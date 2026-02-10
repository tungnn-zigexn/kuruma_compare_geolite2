FROM ruby:3.2.2-slim

# Install build dependencies (for gems like google-cloud-storage if needed)
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev curl

WORKDIR /app

# Copy dependency files
COPY Gemfile Gemfile.lock* ./

# Install bundle
RUN bundle install

# Copy the rest of the application
COPY . .

# Ensure the run script is executable
RUN chmod +x bin/run

# Default command
CMD ["bash", "./bin/run"]
