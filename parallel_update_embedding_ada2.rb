require 'net/http'
require 'uri'
require 'json'
require 'pg'
require 'optparse'
require 'dotenv'

Dotenv.load

# Parse command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: script.rb [options]"

  opts.on("-i", "--instance INSTANCE", "Instance number") do |v|
    options[:instance] = v.to_i
  end

  opts.on("-t", "--total-instances TOTAL", "Total number of instances") do |v|
    options[:total_instances] = v.to_i
  end
end.parse!

# Ensure required options are provided
unless options[:instance] && options[:total_instances]
  puts "Instance number and total number of instances are required."
  exit
end

def fetch_embedding(text, retries: 5, delay: 0.02)
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
    return json_response["data"][0]["embedding"]
  elsif retries > 0 && JSON.parse(response.body)["error"] && JSON.parse(response.body)["error"]["code"] == "rate_limit_exceeded"
    sleep(delay)
    fetch_embedding(text, retries: retries - 1, delay: delay)
  else
    raise "Failed to fetch embedding: #{response.body}"
  end
end

def print_embedding(embedding)
  if embedding.size > 10
    puts "Embedding: #{embedding[0..4].to_s} ... #{embedding[-5..-1].to_s}"
  else
    puts "Embedding: #{embedding}"
  end
end

def update_embeddings(instance, total_instances, page_size: 100)
  conn = PG.connect(dbname: "#{ENV['PGDATABASE']}", user: "#{ENV['PGUSER']}", password: "#{ENV['PGPASSWORD']}")
  
  offset = instance * page_size
  
  loop do
    # Fetch a page of rows, ensuring each instance works on unique data
    result = conn.exec_params('SELECT "Message-ID", content FROM email WHERE embedding_ada2 IS NULL LIMIT $1 OFFSET $2', [page_size, offset])
    break if result.cmd_tuples.zero?
    
    result.each do |row|
      begin
        message_id = row['Message-ID']
        content = row['content']

        # Fetch new embedding
        embedding = fetch_embedding(content)
        print_embedding(embedding)

        # Sleep for a short duration after each successful API call
        sleep(0.02)

        # Update the embedding_ada2 column for the current row
        conn.exec_params('UPDATE email SET embedding_ada2 = $1 WHERE "Message-ID" = $2', [embedding, message_id])
        puts "Updated embedding for row with Message-ID #{message_id}"
      rescue => e
        puts "An error occurred while updating row with Message-ID #{message_id}: #{e.message}"
      end
    end
    
    offset += total_instances * page_size
  end
ensure
  conn&.close
end

update_embeddings(options[:instance], options[:total_instances])
