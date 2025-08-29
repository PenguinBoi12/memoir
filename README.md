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

---

## Installation

```elixir
def deps do
  [
    {:memoir, "~> 0.1.0"}
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
Memoir.cache({:user, 123}, ttl: :timer.minutes(5)) do
  expensive_user_lookup(123)
end
```

You can also interact with the cache directly:

```elixir
Memoir.put({:user, 123}, "value", ttl: :timer.minutes(5))

Memoir.get({:user, 123})

Memoir.delete({:user, 123})

Memoir.clear()
```

## Configuration

You can configure Memoir in your config.exs:
```elixir
config :memoir,
  adapter: Memoir.Adapters.ETS,
  adapter_opts: [ttl: 300_000]
```

You can also configure a cache per module like so:

```elixir
defmodule Greeter do
  use Memoir,
    name: :greeter_cache,
    adapter: Memoir.Adapters.MyAdapter,
    ttl: :timer.minutes(5)

  def greet(name) do
    cache({:greet, name}) do # This will use the configured cache but can be overriden
      "Hello, #{name}!"
    end
  end
end
```

## License

Memoir is released under the GPL-3.0. See [LICENCE](LICENCE)