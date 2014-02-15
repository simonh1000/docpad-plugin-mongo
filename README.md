MongoDB plugin

Example of usage in eco file

`			<ul>
				<% if @gigs.length: %>
					<% for gig in @gigs: %>
						<li><%= gig.date %> <%= gig.location %></li>
					<% end %>
				<% end %>
			</ul>`
