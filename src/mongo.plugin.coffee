#prepare
mongoose = require('mongoose')
Schema = mongoose.Schema

schemaObj = docpad.config.mongo.customSchema
schemaObj._id = {type: Schema.Types.ObjectId, index:true}

gigSchema = new Schema schemaObj, { collection: docpad.config.mongo.query.collection }

Dbdata = mongoose.model 'gigs', gigSchema

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'

		config:
			uristring: (() -> process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				'mongodb://localhost/app22118608')()


			# schema: ( () ->
			# 	customSchema = docpad.config.mongo.customSchema
			# 	customSchema._id = {type: Schema.Types.ObjectId, index:true}
			# 	return new mongoose.Schema customSchema, { collection: docpad.config.mongo.query.collection })()
			
		# Dbdata = mongoose.model 'Dbdata', mongoPlugin.prototype.config.schema

		# Reading data
		# ============
		# opts={} sets opts to default empty object if otherwise null
		getDbData: (opts={}, next) ->
			config = @getConfig()

			# Dbdata = mongoose.model 'gigs', gigSchema
			# Dbdata = new gigModel()
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', -> 
				Dbdata.find docpad.config.mongo.query.predicate, (err, data) ->
					mongoose.connection.close()
					return next(err) if err
					return next(null, data)
			# Chain
			@

		extendTemplateData: (opts,next) ->
			docpad = @docpad
			
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

			# Dbdata = mongoose.model gigSchema
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)

			db.once 'open', ->
				console.log "Adding to database"
				
				# http://metaduck.com/01-asynchronous-iteration-patterns.html
				# http://stackoverflow.com/a/7855281/1923190
				inserted = 0
				report = ""

				for index, item of data
					toUpdate = new Dbdata item
					upsertData = toUpdate.toObject()
					delete upsertData._id
					# we need _id to be null so that a new one is created
					id = if data[index]._id is "" then mongoose.Types.ObjectId() else data[index]._id

					Dbdata.update {_id: id}, upsertData, {upsert:true}, (err) ->			
						if err 
							console.log "plugin: "+err
							report += inserted+" failed"+err+"\n" 
							return
						else report += inserted+" succeeded\n"

						if (++inserted == Object.keys(data).length)
							console.log("All done, closing connection"+report)
							mongoose.connection.close()
							cb report
							return
				@

		removeData: (opts) ->
			config = @getConfig()
			{data, cb} = opts

			mongoose.connect(config.uristring)
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)

			db.once 'open', ->
				# Dbdata = mongoose.model 'Dbdata', schema
				console.log "Removing from database"
				toRemove = new Dbdata data
				toRemove.remove (err, product) ->
					mongoose.connection.close()
					response = if err then err else false
					cb response

		serverExtend: (opts) ->
			{server, express} = opts
			plugin = @
			docpad = @docpad

			server.post '/newdata', (req, res) ->
				console.log 'Received data entries'
				plugin.replaceDbData { data:req.body, cb : (msg) ->
					# console.log ("replaceDbData callback msg="+msg)
					res.setHeader 'Content-Type', 'text/plain'
					res.end msg

					renderOpts =
						path: '/src/index.html.eco',
						renderSingleExtensions:true

					# docpad.action 'render', renderOpts, (err,result) ->
					# 	if err then console.log "regen error "+err

					docpadInstanceConfiguration = {}
					docpadInstance = require('docpad').createInstance( docpadInstanceConfiguration, (err,docpadInstance) -> 
						console.log "docpad instance creation "+err
					)
					
					docpadInstance.action 'render', renderOpts, (err,result) ->
						console.log "Rendering after update complete "+err					
				}

			server.get '/remove', (req, res) ->
				console.log 'Processing removal of'+req.query._id
				plugin.removeData { data:req.query, cb : (err) ->
					console.log ("removal error="+err)
					res.setHeader 'Content-Type', 'text/plain'
					res.end err

					if (!err) 
						renderOpts =
							path: '/src/*.eco',
							renderSingleExtensions:true

						docpad.action 'render', renderOpts, (err,result) ->
							console.log "regen following deletion "+err+" x "+result
				}
