
require('colors')
_ = require('underscore')
fs = require('fs-extra')
qs = require('querystring')
http = require('http')
path = require('path')
async = require('async')

gm = require('gm')
PNG = require('png-js')

module.exports = class Harvester
	constructor: (@cache) ->
		unless @cache and @cache
			throw new Error('Cache is required')
			return

		@options = 
			hostname: 'customization.lego.com'
			port: 80
			method: 'GET'

	harvest: (fn) =>
		console.log("Harvesting bricks".green)
		jsonPath = path.join(@cache, "data.json")
		fs.readFile(jsonPath, 'utf8', (err, json) =>
			# unless err 
			# 	console.log("Returning cached data".green) 
			# 	return fn(null, JSON.parse(json))

			async.waterfall([
				@fetchBricks
				@parseBricks
				@fetchImages
				@parseImages
				@normalizeColors
			], (err, data) =>
				if err then return fn(err)
				fs.outputFile(jsonPath, JSON.stringify(data, null, 2), (err) =>
					if err then return fn(err)
					console.log("Completed brick harvest!".green)
					return fn(null, data)
				)
			)		
		)


	# FETCH ALL BRICKS FROM LEGO


	fetchBricks: (fn) =>
		htmlPath = path.join(@cache, "data.html")
		fs.readFile(htmlPath, 'utf8', (err, data) =>
			unless err 
				fn(null, data)
				return 

			@options.path = '/en-US/pab/service/getBricks.aspx?' + qs.stringify(
				st: 5
				sv: 'allbricks'
				pn: 0
				ps: 2000
				cat: 'NO'
			)
			console.log(('Fetching: ' + path.join('http://', @options.hostname, @options.path)).blue)
			@getHTML(@options, (err, html) =>
				if err then return fn(err)
				fs.outputFile(htmlPath, html, (err) =>
					if err then return fn(err)
					return fn(null, html)
				)
			)
		)

	parseBricks: (html, fn) =>
		regexp = /getBrick\(([0-9]*)\)/g
		matches = _.unique(@matchAll(html, regexp))
		bricks = []

		async.eachLimit(
			matches,
			4,
			(item, fn) =>
				@fetchBrick(item, (err, json) =>
					if err 
						console.log(err)
						return fn(null)
					bricks.push(json)
					fn(null)
				)
			,
			(err) =>
				if err then return fn(err)
				fn(null, bricks)
		)

	# FETCH INDIVIDUAL BRICKS FROM LEGO

	fetchBrick: (id, fn) =>
		brickPath = path.join(@cache, 'bricks/' + id + '.html')
		fs.readFile(brickPath, 'utf8', (err, data) =>
			unless err
				@parseBrick(data, fn)
				return

			@options.path = '/en-US/pab/service/getBrick.aspx?' + qs.stringify(
				itemid: id
				cat: 'NO'
			)
			console.log(('Fetching brick: ' + id).blue)
			@getHTML(@options, (err, html) =>
				if err then return fn(err)
				fs.outputFile(brickPath, html, (err) =>
					if err then return fn(err)
					@parseBrick(html, fn)
				)
			)
		)

	parseBrick: (data, fn) =>
		title = @matchAll(data, /<span id="Label2">([^<]*)<\/span>/g)[0]
		brick = 
			title: title
			colorFamily: @matchAll(data, /<span id="Label4">([^<]*)<\/span>/g)[0]
			colorFamilyId: parseInt(@matchAll(data, /getBricks\(2,([-\d]*)\)/g)[0])
			color: @matchAll(data, /<span id="Label8">([^<]*)<\/span>/g)[0]
			colorId: parseInt(@matchAll(data, /getBricks\(6,([-\d]*)\)/g)[0])
			category: @matchAll(data, /<span id="Label5">([^<]*)<\/span>/g)[0]
			categoryId: parseInt(@matchAll(data, /getBricks\(1,([-\d]*)\)/g)[0])
			itemId: parseInt(@matchAll(data, /<span id="Label6">([^<]*)<\/span>/g)[0])
			designId: parseInt(@matchAll(data, /<span id="Label7">([^<]*)<\/span>/g)[0])
			currency: @matchAll(data, /<span id="Label3">([^<]*)<\/span>/g)[0]
			price: Number(@matchAll(data, /<span id="Label1">([^<]*)<\/span>/g)[0])

		if isNaN(brick.colorId)
			return fn(new Error('"' + brick.title + '" has no colorId and is ignored'))
			
		if isNaN(brick.itemId)
			return fn(new Error('"' + brick.title + '" has no itemId and is ignored'))

		reg = /([\d]{1,3})X([\d]{1,3})[x]?([\d]{0,3})/g
		dimentions = reg.exec(title)
		if dimentions
			if dimentions[1]
				brick.x = parseInt(dimentions[1])
			if dimentions[2]
				brick.y = parseInt(dimentions[2])
			if dimentions[3]
				brick.z = parseInt(dimentions[3])

		fn(null, brick)


	# FETCH BRICK IMAGES FROM LEGO


	fetchImages: (bricks, fn) =>
		async.eachLimit(
			bricks,
			4,
			(brick, fn) =>
				brick.src = path.join('/images/factory/pab/brickSpins/', brick.itemId + '_' + 3 + '.jpg')
				brick.target = path.join(@cache, '/images/', brick.itemId + '.png')
				@fetchImage(brick.src, brick.target, fn)
			,
			(err) =>
				if err then return fn(err)
				fn(null, bricks)
		)

	fetchImage: (src, target, fn) ->
		fs.readFile(target, 'utf8', (err, data) =>
			unless err then return fn(null)

			options =
				host: 'cache.lego.com'
				port: 80
				path: src

			http.get(options, (res) =>
				imagedata = ''
				res.setEncoding('binary')
				res.on('data', (chunk) =>
					imagedata += chunk
				)
				res.on('error', (err) =>
					return fn(err)
				)
				res.on('end', () =>
					fs.outputFile(target, imagedata, 'binary', (err) =>
						if err then return fn(err)
						gm(target)
							# .blur(10, 10)
							.write(target, (err) =>
								fn(null)
							)
					)
				)
			)
		)


	# GET COLOR VALUES FROM THE BRICK IMAGES


	parseImages: (bricks, fn) =>
		async.eachLimit(
			bricks,
			1,
			(brick, fn) =>
				@parseImage(brick, fn)
			,
			(err) =>
				if err then return fn(err)
				fn(null, bricks)
		)

	parseImage: (brick, fn) =>
		@i ?= 0
		index = 100 * 100 * 4 
		PNG.decode(brick.target, (pixels) =>
			i = count = r = g = b = 0
			while i < pixels.length
				pr = pixels[i + 0]
				pg = pixels[i + 1]
				pb = pixels[i + 2]
				if pr < 255 and pg < 255 and pg < 255
					count++
					r += pr
					g += pg
					b += pb
				i+=4
			brighten = 0
			brick.colorRGB = [
				Math.min(255, Math.round(r / count) + brighten)
				Math.min(255, Math.round(g / count) + brighten)
				Math.min(255, Math.round(b / count) + brighten)
			]
			return fn(null)
		)

	normalizeColors: (bricks, fn) =>
		colors = @constructor.unique(bricks, 'colorId', ['colorId'])
		for color in colors
			colorBricks = @constructor.filter(bricks, colorId: color.colorId)
			rgb = undefined

			# gather colors
			for brick in colorBricks
				if rgb is undefined
					rgb = _.clone(brick.colorRGB)
				else
					for c, k in rgb
						rgb[k] += brick.colorRGB[k]

			# average colors
			for c, k in rgb
				rgb[k] /= colorBricks.length
				rgb[k] = Math.round(rgb[k])

			# append colors
			for brick in colorBricks
				brick.colorRGB = rgb
				brick.colorHex = @constructor.rgbToHex(rgb)

		fn(null, bricks)


	# HELPERS


	getHTML: (options, fn) ->
		req = http.request(options, (res) =>
			res.setEncoding('utf8')
			data = ''
			res.on('data', (chunk) =>
				data += chunk
			)
			res.on('end', () =>
				console.log(('Loaded: ' + path.join('http://', @options.hostname, @options.path)).green)
				fn(null, data)
			)
		)
		req.on('error', (err) =>
			fn(err)
		)
		req.end()

	matchAll: (string, regexp, index=1) ->
		matches = []
		while match = regexp.exec(string)
			matches.push(match[index])
		return matches

	# UTILS

	@rgbToHex: (rgb) ->
		return "#" +
			@componentToHex(rgb[0]) + 
			@componentToHex(rgb[1]) + 
			@componentToHex(rgb[2])

	@componentToHex: (c) ->
		hex = c.toString(16)
		if hex.length is 1 
			hex = "0" + hex
		return hex


	# pick
	# return a list of bricks with only the whitelisted keys
	# see underscore's documentation for pick()

	@pick:(bricks, keys) ->
		result = []
		for brick, key in bricks
			result.push(_.pick(brick, keys))
		return result


	# unique
	# Return a list of bricks where one parameter is unique between them and  
	# only the selected keys are included.
	# ie: @unique(bricks, 'colorId', ['colorRBG'])
	# returns a list of all unique colorsId's with their coresponding colorRGB property

	@unique:(bricks, unique, keys) ->
		ids = []
		result = []
		for brick, key in bricks
			if brick[unique]? and ids.indexOf(brick[unique]) is -1
				ids.push(brick[unique])
				result.push(_.pick(brick, keys))
		return result


	# filter
	# Return a list of bricks where all properties matches alle filters
	# ie: @filter(bricks, {title: /Plate 1X1/g, designId: '3024'})
	# "title" has to pass the RegExp and "designId" has to match the string

	@filter:(bricks, filters) ->
		result = []
		for brick, key in bricks
			match = true
			for filterKey, filterValue of filters
				if filterValue instanceof RegExp
					if brick[filterKey].search(filterValue) is -1
						match = false
						break
				else if brick[filterKey] isnt filterValue
					match = false
					break
				
			if match
				result.push(brick)

		return result

	@getPricePrDot: (brick) ->
		brick.price / (brick.x * brick.y)

	@sortByPricePrDot: (bricks) ->
		for brick, key in bricks
			brick.pricePrDot = @getPricePrDot(brick)

		bricks.sort((a, b) ->
			return if a.pricePrDot > b.pricePrDot then 1 else -1
		)
		return bricks

