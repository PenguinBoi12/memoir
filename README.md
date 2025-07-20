# Memoir

> *Caching that feels native to Elixir*

<a href="https://discord.gg/code-society-823178343943897088">
  <img src="https://discordapp.com/api/guilds/823178343943897088/widget.png?style=shield" alt="Join on Discord">
</a>
<a href="https://opensource.org/licenses/gpl-3.0">
  <img src="https://img.shields.io/badge/License-GPL%203.0-blue.svg" alt="License">
</a>
<a href="https://hexdocs.pm/elixir">
  <img src="https://img.shields.io/badge/Elixir-1.18.1-4e2a8e" alt="Elixir">
</a>

Memoir brings effortless, flexible caching to Elixir. Inspired by the elegance of Rails, it lets you cache results with clean macros or decorators, no boilerplate, no fuss. Use ETS, Cachex, or any backend you like with a plug-and-play adapter system. Write expressive, maintainable caching logic that just works.

## Installation

Memoir is not yet available on Hex, so you need to install it directly from GitHub:

```elixir
def deps do
  [
    {:excord, github: "PenguinBoi12/memoir"}
  ]
end
```