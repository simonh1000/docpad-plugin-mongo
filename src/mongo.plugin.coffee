#prepare
async = require("async");
mongoose = require('mongoose')
_ = require("underscore")

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

		# Reading data
		# ============

		extendTemplateData: (opts,next) ->
			# load global and local config data for THIS plugin
			readObject = (item, cb) ->
				# console.log "/readObject: "+item.name
				Dbdata.find item.predicate, (err, data) ->
					if err
						console.log "/readObject: error "+err
						cb err
					else
						# results sorts by date
						opts.templateData[item.name] = data.sort({date:-1})
						cb null

			config = @getConfig()
			
			mongoose.connect(config.uristring)			
			db = mongoose.connection

			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', ->
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
				# console.log '/newdata: received '
				# console.log data
				
				mongoose.connect(config.uristring)			
				db = mongoose.connection
				
				db.on 'error', (err) ->
					docpad.error(err)

				db.once 'open', ->
					async.series([
						# originalRemove,
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
					# finds predicate related to queryName
					pred = config.queryArr.filter( (x) -> return x.name == queryName )
					# use first (and only) element
					Dbdata.remove pred[0].predicate, (err) ->
						if err
							console.log "/original remove error "+err
							return cb err 
						cb null, null

				updateDBItem = (item, cb) ->
					item._id = if item._id is "" then mongoose.Types.ObjectId() else item._id

					toUpdate = new Dbdata item
					upsertData = toUpdate.toObject()
					
					# we need _id to be null so that a new one is created
					delete upsertData._id
					# create id for new gigs
					# should be insert??????
					Dbdata.update {_id: item._id}, upsertData, {upsert:true}, (err) ->			
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
							docpad.pluginsTemplateData[queryName] = _.sortBy results, 'date'
							cb null, null

				generate = (cb) ->
					docpad.action 'generate', collection:docpad.getCollection("gigs"), (err,result) ->
						return cb "/regenerate error "+err if err
						cb null

			server.delete '/remove', (req, res) ->
				id = req.body.id
				console.log(id)
				mongoose.connect(config.uristring)			
				db = mongoose.connection
				
				db.on 'error', (err) ->
					docpad.error(err)

				db.once 'open', ->
					Dbdata.remove {_id: mongoose.Types.ObjectId(id) }, (err) ->
						mongoose.connection.close()	
						if err
							console.log "update error "+err
							res.send(err)
						else
							console.log "sending success"
							res.send(200)
			@