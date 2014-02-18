MongoDB plugin
==============

Add to `docpad.coffee`

	# Define the DocPad Configuration
	docpadConfig = {

		mongo:
			hostname: 'mongodb://<name>:<password>@troup.mongohq.com:10044/',
			database: '<dbName>',
			collection: '<collectionName>',
			schema: {
				# e.g. 
				# town: String,
				# date: String,
				# location: String
			}
	}

	# Export the DocPad Configuration
	module.exports = docpadConfig



Example of usage in eco file

    <ul>
      <% if @<collectionName>.length: %>
        <% for x in @<collectionName>: %>
          <li><%= x.date %> <%= x.location %></li>
        <% end %>
      <% end %>
    </ul>