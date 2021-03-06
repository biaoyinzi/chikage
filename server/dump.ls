#!/usr/bin/env lsc
require! {
  'fs'
  'path'
  'split'
  'kage.json/lib/utils': { parseLine }
  'tarball-extract': 'tarball'
  'redis'
}

const config = rootPath: path.resolve __dirname
const { REDIS_IP = '127.0.0.1', REDIS_PORT = 6379 } = process.env

dump = (done) ->
  client = redis.create-client +REDIS_PORT, REDIS_IP
  client.on 'error' -> console.log it

  glyph-count = 0
  count = 0

  url = 'http://glyphwiki.org/dump.tar.gz'
  err, result <- tarball.extractTarballDownload do
    url
    "#{path.resolve config.rootPath, 'dump.tar.gz'}"
    "#{path.resolve config.rootPath, 'data'}"
    {}
  parents = {}
  fs.createReadStream path.resolve config.rootPath, 'data', 'dump_newest_only.txt'
    .pipe split!
    .on \data (line) ->
      if line is /.*name.*related.*data/ then return

      if line is /^[-+]+$/
        count := 0
        return

      if line is /\((\d+) 行\)/
        total = +RegExp.$1
        if total isnt count
          throw new Error "glyph number mismatched: #count/#total"
        # save parents
        for own id, ps of parents
          client.set "#{id}.parents", (JSON.stringify ps)
        client.quit!
        return done count

      { id, raw }:glyph = parseLine line
      delete glyph.raw

      if not id then return

      # save kage node
      client.set "#{id}", raw
      client.set "#{id}.json", (JSON.stringify glyph)

      # extract parents
      for node in glyph.data when node.type is \link
        parent = parents[node.src] ?= []
        parent.push glyph.id

      ++count

module.exports = dump
