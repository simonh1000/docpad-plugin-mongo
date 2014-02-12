#prepare
mongoose = require('mongoose')

# Export Plugin
module.exports = (BasePlugin) ->

    # Define Plugin
    class mongodbdata extends BasePlugin
		# Plugin name
		name: 'mongodbdata'

		templateData:

			# Fetch list of Gigs
			getGigsData: ->
				mongoose.connect ('mongodb://localhost/gigs')
				db = mongoose.connection;
				db.on 'error', console.error.bind(console, 'connection error:')
				db.once 'open', () -> 
					gigsSchema = mongoose.Schema {
						date : String,
						location: String
					}

					Gigs = mongoose.model 'Gigs', gigsSchema

					Gigs.find (err, gigs) ->
						if err then console.error "db error"
						else return gigs

		# =========================
		# Events

		# Extend Template Data
		extendTemplateData: (existingData) ->
			# Prepare
			{templateData} = existingData

			# Inject template helpers into template data
			for own templateHelperName, templateHelper of @templateData
				console.log.bind console "adding to templateData"+templateHelperName
				templateData[templateHelperName] = templateHelper

			# Chain
			@
