#prepare
mongoose = require('mongoose')
Schema = mongoose.Schema
# config = @getConfig()
schemaObj = docpad.config.plugins.mongo.customSchema
schemaObj._id = {type: Schema.Types.ObjectId, index:true}

gigSchema = new Schema schemaObj, { collection: docpad.config.plugins.mongo.collection }

Dbdata = mongoose.model 'gigs', gigSchema

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'

		config:
			uristring: (() -> process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				'mongodb://localhost/app22118608')()

		# Reading data
		# ============
		# opts={} sets opts to default empty object if otherwise null
		extendTemplateData: (opts,next) ->
			# load global and local config data for THIS plugin
			config = @getConfig()
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', ->
				queries = config.queries
				queryCount = 0
				totalQueries = Object.keys(queries).length

				for index, query of queries
					# could check for ownProperty here
					# Listing 5.18 Javascript Ninja
					((indexClosure) ->
						Dbdata.find query.predicate, (err, data) ->
							opts.templateData[indexClosure] = data
					
							if (++queryCount == totalQueries)
								mongoose.connection.close()
								return next(err) if err
								return next(null, data)
					)(index)
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

					docpad.action 'generate', reset: true, (err,result) ->
						if err then console.log "regen error "+err

					# docpadInstanceConfiguration = {}
					# docpadInstance = require('docpad').createInstance( docpadInstanceConfiguration, (err,docpadInstance) -> 
					# 	console.log "docpad instance creation "+err
					# )
					
					# docpadInstance.action 'generate', (err,result) ->
					# 	console.log "generate after update complete "+err					
				}

			server.get '/remove', (req, res) ->
				console.log 'Processing removal of'+req.query._id
				plugin.removeData { data:req.query, cb : (err) ->
					console.log ("removal error="+err)
					res.setHeader 'Content-Type', 'text/plain'
					res.end err

					if (!err) 
						# renderOpts =
						# 	path: '/src/*.eco',
						# 	renderSingleExtensions:true

						docpad.action 'generate', reset: true, (err,result) ->
							console.log "generate after removal: "+err+" x "+result
				}
