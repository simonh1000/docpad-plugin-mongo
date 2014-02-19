#prepare
mongoose = require('mongoose')

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'


		config:
			uristring= process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				'mongodb://localhost/app22118608'

		uristring= 
			process.env.MONGOLAB_URI || 
			process.env.MONGOHQ_URL || 
			'mongodb://localhost/app22118608'
			
		# Fetch list of Gigs
		# opts={} sets opts to default empty object if otherwise null
		# @ is this
		getDbData: (opts={}, next) ->
			config = @getConfig()
			
			mongoose.connect(uristring)
			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', -> 
				Dbdata = mongoose.model 'Dbdata', docpad.schema

				# cond = {"date": {$gt: new Date()}}

				Dbdata.find docpad.config.mongo.query.predicate, (err, data) ->
					mongoose.connection.close()
					return next(err) if err
					return next(null, data)

			# Chain
			@

		replaceDbData: (opts) ->
			config = @getConfig()
			{data} = opts

			mongoose.connect(uristring)
			
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', -> 
				Dbdata = mongoose.model 'Dbdata', docpad.schema
				console.log "Adding to database "
				`for (var index in data) {
					gig = new Dbdata(data[index]);
					gig.save(function(err, gig){
						if (err) console.log("db save error"+err);
					});
				}`
				mongoose.connection.close()			

		extendTemplateData: (opts,next) ->
			docpad = @docpad
			# config = @getConfig()
			
			docpad.schema = new mongoose.Schema docpad.config.mongo.schema, { collection: docpad.config.mongo.query.collection }

			@getDbData null, (err, data) ->
				return next(err) if err
				opts.templateData[docpad.config.mongo.query.collection] = data
				return next()

			# Chain
			@


		serverExtend: (opts) ->
			{server, express} = opts
			plugin = @

			# server.get '/hello.txt', (req, res) ->
			# 	console.log('Get request received: '+req.query)
			# 	body = "Hello World Simon"
			# 	res.setHeader 'Content-Type', 'text/plain'
			# 	res.end body

			server.post '/hello.txt', (req, res) ->
				console.log 'Received data entries'
				plugin.replaceDbData { data:req.body }
				body = "Hello World Simon"
				res.setHeader 'Content-Type', 'text/plain'
				res.end body
