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

		# extendCollections: (next) ->
		# 	test = docpad.getCollections("html").findAll({isPage:true}, {menuOrder:1})

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
				console.log "/extendTemplateData: reading from database"
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
							console.log "DB update error: "+err
							report += inserted+" failed"+err+"\n"

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
				# console.log "Removing from database"
				toRemove = new Dbdata data
				toRemove.remove (err, product) ->
					mongoose.connection.close()
					# response = if err then err else false
					cb err
					return next()
			@

		serverExtend: (opts) ->
			{server, serverExpress, express} = opts
			plugin = @
			docpad = @docpad

			server.post '/newdata', (req, res, next) ->
				console.log 'Received data entries'
				plugin.replaceDbData { data:req.body, cb : (err) ->
					# res.setHeader 'Content-Type', 'text/plain'
					if (err)
						console.log ("Database update error="+err)
						res.end err
					else 
						console.log "Database update success"
						docpad.action 'generate', reset: true, (err,result) ->
						# docpad.action 'generate', {collection:docpad.getCollection("database")}, (err,result) ->
							if err
								console.log "/update regeneration failed"
								res.send(500, err?.message or err)
								next(err) 
							else
								console.log "/update regeneration success"
								res.send(200, '/update success')
								# next()
				}

			server.get '/remove', (req, res, next) ->
				console.log 'Processing removal of '+req.query._id
				plugin.removeData { data:req.query, cb : (err) ->
					# res.setHeader 'Content-Type', 'text/plain'
					if (err)
						console.log ("removal error="+err)
						res.send(500, err?.message or err)
						next(err)
					else 
						console.log "/remove: Database action succeeded"
						docpad.action 'generate', reset: true, (err,result) ->
						# docpad.action 'generate', {collection:docpad.getCollection("database")}, (err,result) ->
							if err
								console.log "/remove: regeneration failed"+err
								res.send(500, err?.message or err)
								res.body err
								return next(err) 
							else
								console.log "/remove: regeneration success"
								# console.log 'content-type %s', res.get 'Content-Type'
								# 200 is success code
								res.end 'regeneration succeeded'
								
								# res.end false
								# http://stackoverflow.com/a/7789131/1923190 suggests NOT calling next() as I have initiated the body
								# and next() will invoke other functions that try to set headers
								# BUT the false is never actually sent to the client!
								# next()						
					@
				}

			server.get '/test', (req, res, next) ->
				console.log '/test '
				docpad.action 'generate', {}, (err,result) ->
				# docpad.action 'generate server', {collection:docpad.getCollection("database")}, (err,result) ->
					if err
						console.log "/test: error"
						res.send 200, '/test: error'+err
						# return next(err)
					else
						console.log "/test: success"
						# console.log 'content-type %s', res.get 'Content-Type'
						# 200 is success code
						res.end 'regeneration succeeded'
				# res.end

			# chain??
			# @
