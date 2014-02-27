MongoDB plugin
==============

Add to `docpad.coffee`

	# Define the DocPad Configuration
	docpadConfig = {

		[...]

		plugins:

			mongo:
				hostname: 'mongodb://...:...@troup.mongohq.com:10044/'
				# hostname: 'mongodb://localhost/'
				user: ...
				pass: ...
				database: 'app22118608'		
				collection: 'gigs',
				customSchema:
					town: String,
					date: { type: Date, default: Date.now },
					location: String,
					link: String		
				queries:
					futuregigs:
						predicate: {"date": {$gte: new Date()}}
					pastgigs:
						predicate: {"date": {$lt: new Date()}}
	}

	# Export the DocPad Configuration
	module.exports = docpadConfig

Example of usage in eco file

	<% zero_pad = (x) -> if x < 10 then '0'+x else ''+x %>
	<% if @gigs.length: %>
		<% for gig in @futuregigs: %>
			<% mString = gig.date.getFullYear() %>
			<% mString += "-"+ zero_pad (gig.date.getMonth() + 1) %>
			<% mString += "-"+ zero_pad gig.date.getDate() %>
			<input type='hidden' id='queryName' value='futuregigs'>
			<div class="gig-entry">
				<input type="hidden" name="_id" value="<%= gig._id %>">
				<input type="date" name="date" width="20" value="<%- mString %>">
				<input type="textarea" name="location" value="<%= gig.location %>">
				<input type="textarea" name="town" value="<%= gig.town %>">
				<input type="textarea" name="link" value="<%= gig.link %>">
			</div>
		<% end %>
	<% end %>
