## Running heroku-style slugs

Facilitates running [slugfiles](https://devcenter.heroku.com/articles/slug-compiler).

Provides:
- Clean environment, isolation from machine's $PATH
- Signal forwarding
- Port binding validation
- Hostname rewriting (new relic reporting)
- Service Discovery integration (setup/start/update/stop notifications)

### Options

              --slug, -s <s>:   Slug file
            --worker, -w <s>:   Worker type (default: web)
          --instance, -i <i>:   Instance number (default: 1)
      --delayed-bind, -d <i>:   Port bind allowance (default: 0)
              --ping, -p <s>:   Notify state updates
      --ping-interval, -n <i>:   Update interval in seconds (default: 30)
              --env, -e <s+>:   Append to environment
                  --bash, -b:   Run interactive shell
                  --help, -h:   Show this message

## Sample usage
### Local slug

    slugrunner -s ./slug.tgz

### TODO

- write a better readme
