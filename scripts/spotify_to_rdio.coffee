request = require('request')
Rdio    = require('./vendor/rdio/rdio')

rdio    = new Rdio([process.env.RDIO_CLIENT_ID, process.env.RDIO_CLIENT_SECRET])

module.exports = (robot) ->
  robot.hear /(https?:\/\/(www.)?((play|open).spotify.com).+)/i, (msg) ->
    url = msg.match[1]

    urlParseResults = searchTypeAndTokenFromUrl(url)
    searchType      = urlParseResults[0]
    searchToken     = urlParseResults[1]

    if (searchType != '' && searchToken != '')
      refreshSpotifyAuthToken (authToken) ->
        spotifyApiLookup authToken, searchType, searchToken, (spotifyApiResponse) ->
          if searchType == 'track'
            rdioTrackFromSpotifyResponse spotifyApiResponse, (rdioApiResponse) ->
              parseRdioResponseAndRespond(rdioApiResponse, msg)
          else if searchType == 'album'
            rdioAlbumFromSpotifyResponse spotifyApiResponse, (rdioApiResponse) ->
              parseRdioResponseAndRespond(rdioApiResponse, msg)

searchTypeAndTokenFromUrl = (url) ->
  token = ''
  type  = ''

  if (url.indexOf('/track/') != -1)
    type = 'track'
    tokenMatch = url.match(/track\/([^\/]*)/)
    token = tokenMatch[1] if tokenMatch != null
  else if (url.indexOf('/album/') != -1)
    type = 'album'
    tokenMatch = url.match(/album\/([^\/]*)/)
    token = tokenMatch[1] if tokenMatch != null

  return [type, token]

refreshSpotifyAuthToken = (callback) ->
  client_id       = process.env.SPOTIFY_CLIENT_ID
  client_secret   = process.env.SPOTIFY_CLIENT_SECRET
  basic_auth_base64_encoded = new Buffer("#{client_id}:#{client_secret}").toString('base64')

  options = {
    url: 'https://accounts.spotify.com/api/token',
    method: 'POST',
    headers: {
      'Authorization': "Basic #{basic_auth_base64_encoded}"
    },
    form: { 'grant_type': 'client_credentials' }
  }

  request options, (error, response, body) ->
    callback(JSON.parse(body).access_token)

spotifyApiLookup = (authToken, searchType, searchToken, callback) ->
  url = "https://api.spotify.com/v1/#{searchType}s/#{searchToken}"

  options = {
    url: url,
    headers: {
      'Authorization': "Bearer #{authToken}"
    }
  }

  request options, (error, response, body) ->
    callback(body)

rdioTrackFromSpotifyResponse = (response, callback) ->
  # first get artist names, album name, and track from spotify API response
  responseJson = JSON.parse(response)
  artists = (artist.name for artist in responseJson.artists).join(" ")
  album  = responseJson.album.name
  track  = responseJson.name

  # search Rdio API
  rdio.call 'search', { query: "#{artists} #{album} #{track}", types: "Track"}, (err, body) ->
    callback(body)

rdioAlbumFromSpotifyResponse = (response, callback) ->
  # first get artist names and album from spotify API response
  responseJson = JSON.parse(response)
  artists = (artist.name for artist in responseJson.artists).join(" ")
  album  = responseJson.name

  # search Rdio API
  rdio.call 'search', { query: "#{artists} #{album}", types: "Album"}, (err, body) ->
    callback(body)

parseRdioResponseAndRespond = (response, message) ->
  if parseInt(response.result.number_results) > 1
    result_count_line = "Found #{response.result.number_results} Rdio results"
    result_lines = ("#{result.name} - http://www.rdio.com#{result.url}" for result in response.result.results).join("\n")
    message.send "#{result_count_line}:\n #{result_lines}"
  else
    result = response.result.results[0]
    message.send "http://www.rdio.com#{result.url}"
