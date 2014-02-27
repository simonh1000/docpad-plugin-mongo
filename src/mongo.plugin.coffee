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
		conf = docpad.config.plugins.mongo
		name: 'mongo'

		config:
			uristring: (() -> process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				conf.hostname+conf.database)()

		# extendCollections: (next) ->
		# 	test = docpad.getCollections("html").findAll({isPage:true}, {menuOrder:1})

		# Reading data
		# ============

		readData: (obj, queries, cb) ->
			queryCount = 0
			totalQueries = Object.keys(queries).length
			console.log "/readData start"

			for index, query of queries
				# could check for ownProperty here
				# Listing 5.18 Javascript Ninja
				((indexClosure) ->
					Dbdata.find query.predicate, (err, data) ->
						# data is an array, [model]
						obj[indexClosure] = data
				
						if (++queryCount == totalQueries)
							console.log "/readData closing database connection"
							mongoose.connection.close()
							return cb(err) if err
							return cb()
				)(index)
			@

		# opts={} sets opts to default empty object if otherwise null
		extendTemplateData: (opts,next) ->
			# load global and local config data for THIS plugin
			config = @getConfig()
			plugin = @
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', ->
				console.log "/extendTemplateData: reading from database"
				plugin.readData opts.templateData, config.queries, next
			# Chain
			@

		# Data updating
		# =============	
		replaceDbData: (opts) ->
			config = @getConfig()
			{data, cb} = opts
			queryName = data.queryName
			data = data.gigs
			docpad = @docpad

			mongoose.connect(config.uristring)			
			db = mongoose.connection
			
			db.on 'error', (err) ->
				docpad.error(err)

			db.once 'open', ->
				console.log "/replaceDbData Adding to database"
				
				# http://metaduck.com/01-asynchronous-iteration-patterns.html
				# http://stackoverflow.com/a/7855281/1923190
				inserted = 0
				report = null
				tmpPluginData = []

				# remove all future events, as we will be reqriting the database
				Dbdata.remove config.queries[queryName].predicate, (err) ->
					if err
						cb err
					else
						for index, item of data
							toUpdate = new Dbdata item
							# **** YUK hardcoded object name!!!!!! *******
							tmpPluginData.push(toUpdate)
							upsertData = toUpdate.toObject()
							delete upsertData._id
							# we need _id to be null so that a new one is created
							id = if data[index]._id is "" then mongoose.Types.ObjectId() else data[index]._id

							Dbdata.update {_id: id}, upsertData, {upsert:true}, (err) ->			
								if err 
									console.log "DB update error: "+err
									report += inserted+" failed"+err+"\n"
									# mongoose.connection.close()							

								if (++inserted == Object.keys(data).length)
									console.log("/replaceDbData finished")
									docpad.pluginsTemplateData[queryName] = tmpPluginData
									# mongoose.connection.close()
									cb report
			@

		# removeData: (opts) ->
		# 	config = @getConfig()
		# 	{data, cb} = opts

		# 	mongoose.connect(config.uristring)
		# 	db = mongoose.connection
			
		# 	db.on 'error', (err) ->
		# 		docpad.error(err)

		# 	db.once 'open', ->
		# 		# Dbdata = mongoose.model 'Dbdata', schema
		# 		# console.log "Removing from database"
		# 		toRemove = new Dbdata data
		# 		#remove from docpad.pluginsTemplateData['futuregigs'].
		# 		toRemove.remove (err, product) ->
		# 			# mongoose.connection.close()
		# 			console.log err if err
		# 			cb err
		# 	@

		serverExtend: (opts) ->
			{server, serverExpress, express} = opts
			plugin = @
			docpad = @docpad
			config = @getConfig()

			server.post '/newdata', (req, res) ->
				console.log '/newdata: start '
				plugin.replaceDbData { data:req.body, cb : plugin.regenerate }

			# server.get '/remove', (req, res) ->
			# 	console.log '/remove start: removing '+req.query._id
			# 	plugin.removeData { data:req.query, cb : plugin.regenerate }
			#chain
			@

		regenerate: (err) ->
			docpad = @docpad
			# res.setHeader 'Content-Type', 'text/plain'
			mongoose.connection.close()
			if (err)
				console.log ("/regenerate passed error="+err)
				res.send(500, err?.message or err)
				# next(err)
			else 
				console.log "/regenerate: Database action succeeded"
				# https://github.com/bevry/staticsitegenerators/blob/master/docpad.coffee#L222
				genOpts=
					collection:docpad.getCollection("gigs")
					# reset: true  # default
				
				docpad.action 'generate', genOpts, (err,result) ->
					if err
						console.log "/regenerate error"
						res.send(500, err?.message or err)
					else
						console.log "/regenerate success"
						res.send(200, "regenerated")
			@
