#prepare
mongoose = require('mongoose')
Schema = mongoose.Schema

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		Dbdata = {}

		name: 'mongo'

		config:
			uristring: (() -> process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				'mongodb://localhost/app22118608')()
			customSchema:
				_id: Schema.Types.ObjectId,
				town: String,
				date: { type: Date, default: Date.now },
				location: String,
				link: String
			schema: new mongoose.Schema docpad.config.mongo.customSchema, { collection: docpad.config.mongo.query.collection }

		# uristring= 
		# 	process.env.MONGOLAB_URI || 
		# 	process.env.MONGOHQ_URL || 
		# 	'mongodb://localhost/app22118608'
			
		# Reading data
		# ============
		# opts={} sets opts to default empty object if otherwise null
		getDbData: (opts={}, next) ->
			config = @getConfig()
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			# schema = new mongoose.Schema config.customSchema, { collection: docpad.config.mongo.query.collection }

			db.once 'open', -> 
				Dbdata = mongoose.model 'Dbdata', config.schema

				Dbdata.find docpad.config.mongo.query.predicate, (err, data) ->
					mongoose.connection.close()
					return next(err) if err
					return next(null, data)

			# Chain
			@

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

		# Data updating
		# =============	
		replaceDbData: (opts) ->
			config = @getConfig()
			{data, cb} = opts

			mongoose.connect(config.uristring)			
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)

			# schema = new mongoose.Schema config.customSchema, { collection: docpad.config.mongo.query.collection }

			db.once 'open', ->
				# Dbdata = mongoose.model 'Dbdata', schema
				console.log "Adding to database"
				
				# http://metaduck.com/01-asynchronous-iteration-patterns.html
				# http://stackoverflow.com/a/7855281/1923190
				inserted = 0
				report = ""

				for index, item of data
					toUpdate = new Dbdata item
					upsertData = toUpdate.toObject()
					delete upsertData._id

					Dbdata.update {_id:toUpdate._id}, upsertData, {upsert:true}, (err) ->			
						if err 
							# mongoose.connection.close()
							console.log err
							report += inserted+" failed\n" 
							return
						else report += inserted+" succeeded\n" 

						if (++inserted == Object.keys(data).length)
							console.log("All done, closing connection"+report)
							mongoose.connection.close()
							cb report
							return
				@				

		serverExtend: (opts) ->
			{server, express} = opts
			plugin = @

			server.post '/newdata', (req, res) ->
				console.log 'Received data entries'
				plugin.replaceDbData { data:req.body, cb : (msg) ->
					console.log("callback msg="+msg)
					res.setHeader 'Content-Type', 'text/plain'
					res.end msg
				}
