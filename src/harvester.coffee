
# parameters = 
# 	sid: Math.random()
# 	itemid: ''
# 	st: 5 # search type (0= Brick Name, 1=Category, 2=Color Family, 3=Element ID, 4:Design ID, 5:Allbricks, 6:Exact Color)
# 	sv: 'allbricks' # search term
# 	pn: 0 # page number
# 	ps: 2000 # page length
# 	cat: 'NO' # locale

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
	constructor: (@cachePath) ->
		@cachePath ?= path.join(__dirname, "../cache/")
		@options = 
			hostname: 'customization.lego.com'
			port: 80
			method: 'GET'

	fetch: (fn) =>
		console.log("Fetch bricks")
		jsonPath = path.join(@cachePath, "data.json")
		fs.readFile(jsonPath, 'utf8', (err, json) =>
			unless err then return fn(null, JSON.parse(json))

			async.waterfall([
				@fetchBricks
				@parseBricks
				@fetchImages
				@parseImages
			], (err, data) =>
				if err then return fn(err)
				fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2))
				return data
			)		
		)


	# FETCH ALL BRICKS FROM LEGO


	fetchBricks: (fn) =>
		htmlPath = path.join(@cachePath, "data.html")
		fs.readFile(htmlPath, 'utf8', (err, data) =>
			unless err then return fn(null, data)

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
		console.log('Parsing data'.blue, '\n')

		regexp = /getBrick\(([0-9]*)\)/g
		matches = _.unique(@matchAll(html, regexp))
		bricks = []

		async.eachLimit(
			matches,
			4,
			(item, fn) =>
				@fetchBrick(item, (err, json) =>
					if err then return fn(err)
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
		brickPath = path.join(@cachePath, 'bricks/' + id + '.html')
		fs.readFile(brickPath, 'utf8', (err, data) =>
			unless err
				@parseBricks(data, (err, json) =>
					return fn(null, json)
				)
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
					@parseBricks(html, (err, json) =>
						return fn(null, json)
					)
				)
			)
		)

	parseBricks: (data, fn) =>
		title = @matchAll(data, /<span id="Label2">([^<]*)<\/span>/g)[0]
		brick = 
			title: title
			colorFamily: @matchAll(data, /<span id="Label4">([^<]*)<\/span>/g)[0]
			colorFamilyId: @matchAll(data, /getBricks\(2,([-\d]*)\)/g)[0]
			color: @matchAll(data, /<span id="Label8">([^<]*)<\/span>/g)[0]
			colorId: @matchAll(data, /getBricks\(6,([-\d]*)\)/g)[0]
			category: @matchAll(data, /<span id="Label5">([^<]*)<\/span>/g)[0]
			categoryId: @matchAll(data, /getBricks\(1,([-\d]*)\)/g)[0]
			itemId: @matchAll(data, /<span id="Label6">([^<]*)<\/span>/g)[0]
			designId: @matchAll(data, /<span id="Label7">([^<]*)<\/span>/g)[0]
			currency: @matchAll(data, /<span id="Label3">([^<]*)<\/span>/g)[0]
			price: @matchAll(data, /<span id="Label1">([^<]*)<\/span>/g)[0]

		reg = /([\d]{1,3})X([\d]{1,3})[x]?([\d]{0,3})/g
		dimentions = reg.exec(title)
		if dimentions
			if dimentions[1]
				brick.x = dimentions[1]
			if dimentions[2]
				brick.y = dimentions[2]
			if dimentions[3]
				brick.z = dimentions[3]

		fn(null, brick)


	# FETCH BRICK IMAGES FROM LEGO


	fetchImages: (bricks, fn) =>
		async.eachLimit(
			bricks,
			4,
			(brick, fn) =>
				brick.src = path.join('/images/factory/pab/brickSpins/', brick.itemId + '_' + 3 + '.jpg')
				brick.target = path.join(@cachePath, 'bricks/images/', brick.itemId + '.png')
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
					fs.writeFile(target, imagedata, 'binary', (err) =>
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
		console.log(">>", brick.target, @i++)
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
			brick.colorRGB = 
				r: Math.min(255, Math.round(r / count) + brighten)
				g: Math.min(255, Math.round(g / count) + brighten)
				b: Math.min(255, Math.round(b / count) + brighten)
				a: 255
			brick.colorHex = @rgbToHex(brick.colorRGB.r, brick.colorRGB.g, brick.colorRGB.b)
			return fn(null)
		)


	# UTILS


	getHTML: (options, fn) =>
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

	matchAll: (string, regexp, index=1) =>
		matches = []
		while match = regexp.exec(string)
			matches.push(match[index])
		
		return matches

	rgbToHex: (r, g, b) =>
		return "#" + @componentToHex(r) + @componentToHex(g) + @componentToHex(b)

	componentToHex: (c) ->
		hex = c.toString(16)
		if hex.length is 1 
			hex = "0" + hex
		return hex

