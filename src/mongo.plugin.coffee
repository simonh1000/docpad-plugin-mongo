#prepare
mongoose = require('mongoose')
Schema = mongoose.Schema

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'

		config:
			uristring: () -> process.env.MONGOLAB_URI || 
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
				# Take client's schema and add _id field
				schema = docpad.schema
				schema["_id"] = Schema.Types.ObjectId
				Dbdata = mongoose.model 'Dbdata', schema

				Dbdata.find docpad.config.mongo.query.predicate, (err, data) ->
					mongoose.connection.close()
					return next(err) if err
					return next(null, data)

			# Chain
			@

		replaceDbData: (opts) ->
			config = @getConfig()
			{data, cb} = opts

			mongoose.connect(uristring)
			
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', ->
				# Take client's schema and add _id field
				schema = docpad.schema
				Dbdata = mongoose.model 'Dbdata', schema

				console.log "Adding to database"
				
				# http://metaduck.com/01-asynchronous-iteration-patterns.html
				inserted = 0

				for index, item of data
					toUpdate = new Dbdata item
					toUpdate.save (err, itemEntered) ->			
						if err 
							mongoose.connection.close()
							cb "failed" 
							return
						if (++inserted == data.length)
							mongoose.connection.close()
							cb "success"
							return
				@				

		extendTemplateData: (opts,next) ->
			docpad = @docpad
			# config = @getConfig()
			
			# create schema, tied to relevant collection, to be used to create model
			cSchema = docpad.config.mongo.customSchema
			cSchema["_id"] = Schema.Types.ObjectId

			docpad.schema = new mongoose.Schema cSchema, { collection: docpad.config.mongo.query.collection }

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

			server.post '/newdata', (req, res) ->
				console.log 'Received data entries'
				plugin.replaceDbData { data:req.body, cb : (msg) ->
					console.log("callback msg="+msg)
					res.setHeader 'Content-Type', 'text/plain'
					res.end msg
				}
