FROM ruby:3.4.1

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  postgresql-client

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems WITHOUT development and test groups
RUN bundle install

# Copy application code
COPY . .

# Expose port 3000
EXPOSE 3000