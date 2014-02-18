#prepare
mongoose = require('mongoose')

# Export Plugin
module.exports = (BasePlugin) ->
	class mongoPlugin extends BasePlugin
		name: 'mongo'

		dbSchema = new mongoose.Schema docpad.config.mongo.schema, { collection: docpad.config.mongo.collection }

		# Fetch list of Gigs
		# opts={} sets opts to default empty object if otherwise null
		# @ is this
		getDbData: (opts={}, next) ->
			config = @getConfig()
			# console.log('config: '+config)
			docpad = @docpad

			uristring = 
				process.env.MONGOLAB_URI || 
				process.env.MONGOHQ_URL || 
				'mongodb://localhost/app22118608';
			
			mongoose.connect(uristring)
			db = mongoose.connection
			db.on 'error', (err) ->
				docpad.error(err)  # you may want to change this to `return next(err)`

			db.once 'open', -> 
				dbData = mongoose.model('dbData', dbSchema)

				dbData.find {}, (err, data) ->
					mongoose.connection.close()
					return next(err) if err
					return next(null, data)

			# Chain
			@

		extendTemplateData: (opts,next) ->
			@getDbData null, (err, data) ->
				return next(err) if err
				opts.templateData[docpad.config.mongo.collection] = data
				return next()

			# Chain
			@