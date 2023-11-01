require 'net/http'
require 'uri'
require 'json'
require 'pg'
require 'terminal-table'
require 'benchmark'
require 'dotenv'

Dotenv.load

def fetch_embedding(text)
  uri = URI.parse("https://api.openai.com/v1/embeddings")
  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{ENV['OPENAI_API_KEY']}"
  request.body = JSON.dump({
    "input" => text,
    "model" => "text-embedding-ada-002"
  })

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    json_response = JSON.parse(response.body)
    return json_response["data"][0]["embedding"] || []
  else
    raise "Failed to fetch embedding: #{response.body}"
  end
end

def print_embedding(embedding)
  return if embedding.nil?
  if embedding.size > 10
    puts "Embedding: #{embedding[0..4].to_s} ... #{embedding[-5..-1].to_s}"
  else
    puts "Embedding: #{embedding}"
  end
end

def truncate_text(text, max_length)
  return "" if text.nil?
  text.length > max_length ? "#{text[0...max_length-3]}..." : text
end

def list_nearest_email(embedding, text_data)
  conn = PG.connect(
    dbname: ENV['PGDATABASE'],
    host: ENV['PGHOST'],
    user: ENV['PGUSER'],
    password: ENV['PGPASSWORD'],
    port: ENV['PGPORT']
  )

  query = <<~SQL
    SELECT DISTINCT ON ("Subject")
        "Message-ID",
        "Subject",
        "Date",
        content
    FROM (
        SELECT
            "Message-ID",
            "Date",
            "Subject",
            content
        FROM
            email
        WHERE
            embedding_ada2 IS NOT NULL
        ORDER BY
            embedding_ada2 <-> $1
        LIMIT 100
    ) subquery
    ORDER BY
        "Subject",
        "Date" DESC,
        "Message-ID"
    LIMIT 10;
  SQL



  conn.exec_params(query, [embedding]) do |result|
    puts "\nResults for '#{text_data}':"

    rows = []
    result.each_with_index do |row, index|
      message_id = truncate_text(row['Message-ID'], 50)
      date = truncate_text(row['Date'], 20)
      subject = truncate_text(row['Subject'], 30)
      content = truncate_text(row['content'], 50)
      rows << [index + 1, message_id, date, subject, content]
    end

    table = Terminal::Table.new headings: ['No', 'Message-ID', 'Date', 'Subject', 'Content'], rows: rows
    puts table
  end
ensure
  conn&.close
end


def benchmark_query(embedding, text_data)
  table = Terminal::Table.new headings: ['Task', 'Time (s)'], rows: []

  time_for_embedding = Benchmark.realtime do
    fetch_embedding(text_data)
  end
  table.add_row(['Fetch Embedding', time_for_embedding.round(4)])

  time_for_query = Benchmark.realtime do
    list_nearest_email(embedding, text_data)
  end
  table.add_row(['Database Query', time_for_query.round(4)])

  puts table
end

loop do
  print "Enter a query for the email DB (or type 'quit' to exit): "
  text_data = gets.chomp
  break if text_data.downcase == 'quit'

  begin
    embedding = fetch_embedding(text_data)
    print_embedding(embedding)
    benchmark_query(embedding, text_data)
  rescue => e
    puts "An error occurred: #{e.message}"
  end
end
