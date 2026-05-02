FROM ruby:4.0.3

RUN apt-get update -qq && apt-get install -y \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p tmp/pids

EXPOSE $PORT

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["sh", "-c", "bin/rails server -b 0.0.0.0 -p ${PORT:-3000}"]
