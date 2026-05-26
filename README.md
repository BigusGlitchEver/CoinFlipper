# Coin Flipper

A kid's tabletop conquest game with roguelite progression and an idle/clicker meta-layer.

You're a chubby kid with a lollipop and a too-small shirt, flipping your way from your neighborhood all the way to space, taking over buildings, earning Marbles, and becoming the best.

Built in [LÖVE 2D](https://love2d.org) (Lua).

## Tone & Art

Schoolyard swagger. Slay the Spire's casual cool meets Cookie Clicker's absurd escalation. All in-game visuals are hand-drawn by the developer — rough lines, personal style, no polish hiding. The rawness is the aesthetic.

## Core Loop

`Map → Pick House → Floor 1 → Shop → Floor 2 → Shop → Floor 3 → Shop → Boss Decision → Boss Flip or Walk Away → Win/Lose → Map`

## Prototype Scope

- 3 houses in a cul-de-sac (Grandma, The Cat, Gym Bro)
- 4 flip items (Coin, Lucky Coin, Toast, Pancakes)
- 3-floor structure with shrinking zones and rising thresholds
- Shop run by the Nerdy Kid between every floor
- 3-4 Bicycle cards as modifiers
- Boss flip with tug-of-war bar
- One random event (Angel or Demon)
- Passive Marble generation from conquered buildings
- Per-building and district upgrades
- Persistent global Marble bank
- Special Marble jackpot event

## Project Layout

```
main.lua                       entry point
conf.lua                       LÖVE configuration
gamestate.lua                  state machine
gamestates/
  map.lua                      neighborhood map
  run.lua                      flip board (3 floors)
  shop.lua                     Nerdy Kid shop
  boss.lua                     boss flip + tug-of-war
components/
  buildings/manager.lua        conquered buildings + passive income
  cards/manager.lua            Bicycle card system
  flipboard/board.lua          zones, scoring, multiplier chain
  marbles/bank.lua             global currency
data/
  buildings.lua                3 prototype houses
  cards.lua                    Bicycle cards
  flip_items.lua               Coin / Lucky Coin / Toast / Pancakes
helpers/
  probability.lua              weighted picks, lerp
lib/
  tween.lua                    animation tweening
assets/
  music/                       background tracks (5 anafuda tracks + bg images)
  sfx/                         button + sweep sounds
```

## Running

Install [LÖVE 11.x](https://love2d.org) and run:

```
love .
```

(from the project root)
