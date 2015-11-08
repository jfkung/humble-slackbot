request = require('request')
cheerio = require('cheerio')

artist  = ''
album   = ''
track   = ''

module.exports = (robot) ->
  robot.hear /(https?:\/\/(www.)?(rd.?io).+)/i, (msg) ->

    # expand shortened urls
    if (msg.match[1].indexOf('http://rd.io/x/') != -1)
      request
        method: 'HEAD'
        url: msg.match[1]
        followAllRedirects: true
      , (error, response) ->
        expandedUrl = response.request.href
        msg.send rdioSongInfoFromUrl(expandedUrl)
        spotifyLinkFromRdioUrl(msg, expandedUrl)
    else
      msg.send rdioSongInfoFromUrl(msg.match[1])
      spotifyLinkFromRdioUrl(msg, msg.match[1])

artistFromUrl = (url) ->
  artist = ''
  artistMatch = url.match(/artist\/([^\/]*)/)

  if artistMatch != null
    artist = artistMatch[1].replace(/_/g,' ')

  return artist

albumFromUrl = (url) ->
  album = ''
  albumMatch = url.match(/album\/([^\/]*)/)

  if albumMatch != null
    album = albumMatch[1].replace(/_/g,' ')

  return album

trackFromUrl = (url) ->
  track = ''
  trackMatch = url.match(/track\/([^\/]*)/)

  if trackMatch != null
    track = trackMatch[1].replace(/_/g,' ')

  return track

rdioSongInfoFromUrl = (url) ->
  responseString = ''

  artist = artistFromUrl(url)
  responseString += "Artist: #{artist}, " if artist != ''

  album = albumFromUrl(url)
  responseString += "Album: #{album}" if album != ''

  track = trackFromUrl(url)
  responseString += ", Track: #{track}" if track != ''

  return responseString

spotifyLinkFromRdioUrl = (msg, url) ->
  artist = artistFromUrl(url)
  album  = albumFromUrl(url)
  track  = trackFromUrl(url)

  url = "http://www.stewsnooze.com/searchify/?q=#{artist}+#{album}+#{track}"

  request url, (error, response, html) ->
    unless error
      $ = cheerio.load(html)

      $('.results').filter ->
        data = $(this)
        results = []

        for result in data.children()
          result = $(result)
          if track != ''
            trackMatch = result.html().match(/(spotify:track([^"])*)/)
            resultText = "#{result.text()} -- #{convertSpotifyResultToLink(trackMatch[1])}"
            results.push resultText if trackMatch != null
            # check for an exact match
            if result.text() == "#{artist} - #{album} - #{track}"
              results = []
              results.push resultText
              break
          else
            albumMatch = result.html().match(/(spotify:album([^"])*)/)
            resultText = "#{result.text()} -- #{convertSpotifyResultToLink(albumMatch[1])}"
            results.push resultText if albumMatch != null
            # check for an exact match
            if result.text() == "#{artist} - #{album}"
              results = []
              results.push resultText
              break

        if results.length > 1
          result_count_line = "Found #{results.length} Spotify results"
          msg.send "#{result_count_line}:\n #{results.join('\n')}"
        else
          msg.send results

        return

convertSpotifyResultToLink = (result) ->
  responseString = 'https://play.spotify.com/'
  resultToken = result.match(/.+:(.+)$/)

  if result.indexOf('spotify:track:') == 0
    responseString += "track/#{resultToken[1]}"
  else
    responseString += "album/#{resultToken[1]}"

  return responseString
