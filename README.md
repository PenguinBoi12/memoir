# Memoir

> *Caching that feels native to Elixir*

<a href="https://discord.gg/code-society-823178343943897088">
  <img src="https://discordapp.com/api/guilds/823178343943897088/widget.png?style=shield" alt="Join on Discord">
</a>
<a href="https://opensource.org/licenses/gpl-3.0">
  <img src="https://img.shields.io/badge/License-GPL%203.0-blue.svg" alt="License: GPL 3.0">
</a>
<a href="https://hexdocs.pm/elixir">
  <img src="https://img.shields.io/badge/Elixir-1.18.1-4e2a8e" alt="Elixir">
</a>

---

**Memoir** brings effortless and expressive caching to Elixir. Inspired by the simplicity of Rails’ `fetch` API, Memoir gives you:

- A clean `cache/3` block interface
- Optional `@cache` decorators for function-level memoization
- Pluggable backends (ETS, Cachex, or your own)
- Minimal setup, maximum flexibility

Write readable, maintainable caching logic without boilerplate.

---

## Installation

Memoir is not yet published on Hex. Add it directly from GitHub:

```elixir
def deps do
  [
    {:memoir, github: "PenguinBoi12/memoir"}
  ]
end
```

Start the application by adding it to your supervision tree:

```elixir
children = [
  Memoir
]
```

## Usage

Memoir is typically used to cache expensive function calls:

```elixir
Memoir.cache({:user, 123}, expire_in: :timer.minutes(5)) do
  expensive_user_lookup(123)
end
```

You can also interact with the cache directly:
```elixir
Memoir.put(:some_key, "value", ttl: 60_000)
Memoir.get(:some_key)
Memoir.delete(:some_key)
Memoir.clear()
```

You can also configure a cache per module like so
```elixir
defmodule Greeter do
  use Memoir,
    name: :greeter_cache
    adapter: Memoir.Adapters.MyAdapter,
    ttl: :timer.minutes(5)

  def greet(name) do
    cache({:greet, name}) do # This will use the configured cache
      "Hello, #{name}!"
    end
  end
end
``` 

## Configuration

You can configure Memoir in your config.exs:
```elixir
config :memoir,
  adapter: Memoir.Adapters.ETS,
  adapter_opts: [ttl: 300_000]
```

## Features

- Memoization with function decorators

- Block-based caching like Rails.cache.fetch

- Pluggable backends (Cachex, ETS, etc.)

- Safe and side-effect-free lazy evaluation

- Minimal setup, works out of the box

## License

Memoir is released under the GPL-3.0. See [LICENCE](LICENCE)