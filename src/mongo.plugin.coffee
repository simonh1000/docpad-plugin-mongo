#prepare
mongoose = require('mongoose')

# Export Plugin
module.exports = (BasePlugin) ->

	# Define Plugin
	class mongoPlugin extends BasePlugin
		# Plugin name
		name: 'mongo'

		# Fetch list of Gigs
		getGigsData: (opts) ->
			mongoose.connect ('mongodb://localhost/test')
			db = mongoose.connection;
			db.on 'error', console.error.bind(console, 'connection error:')
			db.once 'open', () -> 
				gigsSchema = mongoose.Schema {
					date : String,
					location : String
				}

				Gigs = mongoose.model 'Gigs', gigsSchema

				Gigs.find {}, (err, gigs) ->
					mongoose.connection.close()
					if err then console.error "db error"
					else 
						console.dir gigs
						opts["getGigsData"] = gigs
						opts.templateData["getGigsData"] = gigs
						return gigs

		# =========================
		# Events

		# Extend Template Data
		extendTemplateData: (opts) ->
			# {templateData} = opts

			# getGigsData = () ->
			# 	g = { "date" : "3-4-2013", "location" : "Gent" }
			# 	return g

			# opts.templateData["getGigsData"] = @getGigsData()
			@getGigsData(opts)
