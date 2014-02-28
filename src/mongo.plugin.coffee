#prepare
async = require("async");
mongoose = require('mongoose')

Schema = mongoose.Schema
conf = docpad.config.plugins.mongo
schemaObj = conf.customSchema
schemaObj._id = {type: Schema.Types.ObjectId, index:true}
gigSchema = new Schema schemaObj, { collection: conf.collection }

Dbdata = mongoose.model 'gigs', gigSchema

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'

		config:
			uristring: (() -> 
				process.env.MONGOLAB_URI || process.env.MONGOHQ_URL || conf.hostname+conf.database
			)()
			# queryArr: [
			# 	name: "futuregigs"
			# 	predicate: {"date": {$gte: new Date()}}
			# ,
			# 	name: "pastgigs"
			# 	predicate: {"date": {$lt: new Date()}}
			# ]

		# Reading data
		# ============

		extendTemplateData: (opts,next) ->
			# load global and local config data for THIS plugin
			config = @getConfig()
			
			readObject = (item, cb) ->
				# console.log "/readObject: "+item.name
				Dbdata.find item.predicate, (err, data) ->
					if err
						console.log "/readObject: error "+err
						cb err
					else
						opts.templateData[item.name] = data
						cb null

			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', ->
				console.log "/extendTemplateData: reading from database "+config.uristring

				async.each config.queryArr, readObject, (err) ->
					mongoose.connection.close()
					if err
						console.log "async.each error: "+err
						next(err)
					else next()

			# Chain
			@

		# Data updating
		# =============	
		serverExtend: (opts) ->
			# opts={} sets opts to default empty object if otherwise null
			{server} = opts
			config = @getConfig()
			docpad = @docpad

			server.post '/newdata', (req, res) ->
				data = req.body		
				queryName = data.queryName
				data = data.gigs
				console.log '/newdata: received '
				console.log data
				
				mongoose.connect(config.uristring)			
				db = mongoose.connection
				
				db.on 'error', (err) ->
					docpad.error(err)

				db.once 'open', ->
					async.series([
						originalRemove,
						updateDB,
						generate
					],
					(err, results) ->
						if err
							console.log "final error "+err
							res.send(500, err?.message or err)
						else
							console.log "success"
							res.send(200, false)
					)

				originalRemove = (cb) ->
					# ******** ELIMINATE HARDCODING ***************************************************
					pred = config.queryArr[0].predicate
					Dbdata.remove pred, (err) ->
						if err
							console.log "/original remove error "+err
							return cb err 
						cb null, null

				updateDBItem = (item, cb) ->
					toUpdate = new Dbdata item
					upsertData = toUpdate.toObject()
					
					# we need _id to be null so that a new one is created
					delete upsertData._id
					# create id for new gigs
					id = if item._id is "" then mongoose.Types.ObjectId() else item._id

					# should be insert????????????????
					Dbdata.update {_id: id}, upsertData, {upsert:true}, (err) ->			
						if err
							console.log "update error "+err
							return cb err
						else cb null, toUpdate

				updateDB = (cb) ->
					async.concat data, updateDBItem, (err, results) ->
					# async.each data, updateDBItem, (err) ->
						mongoose.connection.close()
						if err
							console.log "/updateDb error "+err
							cb err
						else
							docpad.pluginsTemplateData[queryName] = results
							cb null, null

				generate = (cb) ->
					docpad.action 'generate', collection:docpad.getCollection("gigs"), (err,result) ->
						return cb "/regenerate error "+err if err
						cb null