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
				return """
					this should be database data
					"""


		# =========================
		# Events

		# Extend Template Data
		extendTemplateData: (existingData) ->
			# Prepare
			{templateData} = existingData

			# Inject template helpers into template data
			console.log "adding to templateData"
			templateData["getGigsData"] = getGigsData

			# Chain
			@
