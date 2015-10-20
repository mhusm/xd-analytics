Templates.App = React.createClass
	mixins: [ReactMeteorData]
	views:
		overview: "Overview"
		timeline: "Timeline"
		devices: "Devices"
		logs: "Logs"
	getMeteorData: ->
		handle = Meteor.subscribe 'app', @props.appId

		app = Apps.findOne @props.appId

		logs = Logs.find
				appId: @props.appId
			,
				sort:
					loggedAt: -1
			.fetch()

		devices = Devices.find
				appId: @props.appId
			,
				sort:
					lastUpdatedAt: -1
			.fetch()

		ready: handle.ready()
		app: app
		logs: logs
		devices: devices
	view: ->
		if @props.view then @props.view else "overview"
	viewUrl: (view) ->
		if view is "overview"
			"/apps/#{@props.appId}"
		else
			"/apps/#{@props.appId}/#{view}"
	render: ->
		<article className="container">
			{
				if @data.ready
					if @data.app
						<div className="row">
							<div className="col-xs-12">
								<h1>{@data.app.name}</h1>
								<p>{@data.app.description}</p>
							</div>
						</div>
					else
						<div className="row">
							<div className="col-xs-12">
								<h1>Not found</h1>
								<p>This app doesn't exist. <a href="/apps">Back to your apps</a>.</p>
							</div>
						</div>
				else
					<div className="row">
						<div className="col-xs-12">
							<h1>Loading App<Templates.Ellipsis/></h1>
						</div>
					</div>
			}
			{
				if not @data.ready or @data.app
					<div className="row">
						<div className="col-xs-12">
							<ul className="nav nav-tabs">
								{
									for view, label of @views
										<li key={view} role="presentation" className={if view is @view() then "active" else ""}><a href={@viewUrl(view)}>{label}</a></li>
								}
							</ul>
						</div>
					</div>
			}
			<div className="row">
				{
					if @data.ready
						if @data.app
							switch @view()
								when "overview"
									<Views.Overview app={@data.app} devices={@data.devices} logs={@data.logs}/>
								when "timeline"
									<Views.Timeline appId={@props.appId}/>
								when "devices"
									<Views.Devices appId={@props.appId} devices={@data.devices}/>
								when "logs"
									<Views.Logs logs={@data.logs}/>
					else
						<Templates.Loading />
				}
			</div>
		</article>

Views = {}

Views.Overview = React.createClass
	mixins: [ReactUtils]
	render: ->
		<div>
			<div className="col-xs-12 col-sm-6">
				<h2>App data</h2>
				<div>
					<label>App ID:&nbsp;</label>
					{@props.app._id}
				</div>
				<div>
					<label>API Key:&nbsp;</label>
					{@props.app.apiKey}
				</div>
			</div>
			<div className="col-xs-12 col-sm-6">
				<h2>Statistics</h2>
				<div>
					<label>Number of devices:&nbsp;</label>
					{@props.devices.length}
				</div>
				<div>
					<label>Number of log entries:&nbsp;</label>
					{@props.logs.length}
				</div>
			</div>
		</div>


Views.Timeline = React.createClass
	mixins: [ReactMeteorData, ReactUtils]
	displays:
		logs: "Number of logs"
		users: "Users"
		devices: "Devices"
		views: "Page views"
		logins: "Logins"
		logouts: "Logouts"
		uniquePages: "Unique page views"
		maxDevices: "Max devices per user"
		browsers: "Browsers"
		browserVersions: "Browser versions"
		oses: "Operating systems"
		pages: "Pages"
	getInitialState: ->
		from: moment().subtract(7, 'days').toDate()
		to: new Date()
		display: 'logs'
	componentDidMount: ->
		@timeline = document.getElementById("timeline")

		if @data.logs
			@update @data.logs
	getMeteorData: ->
		find =
			appId: @props.appId

		if @state.from or @state.to
			find.loggedAt = {}
		if @state.from
			find.loggedAt.$gte = @state.from
		if @state.to
			find.loggedAt.$lte = @state.to

		logs = Logs.find find,
				sort:
					loggedAt: 1
			.fetch()

		@update logs

		logs: logs
	timeline: null
	chart: null
	currentChart: null

	update: (logs) ->
		if not logs
			return

		date = (point) ->
			point.loggedAt

		switch @state.display
			when "logs"
				start = -> 0
				combine = (values, index, element) ->
					values[index]++
				reduce = (values, index) ->
					values[index] = values[index]
				@lineChart logs, date, start, combine, reduce

			when "users"
				start = -> {}
				combine = (values, index, element) ->
					if element.userIdentifier
						values[index][element.userIdentifier] = 1
				reduce = (values, index) ->
					values[index] = Object.keys(values[index]).length
				@lineChart logs, date, start, combine, reduce

			when "devices"
				start = -> {}
				combine = (values, index, element) ->
					if element.device.id
						values[index][element.device.id] = 1
				reduce = (values, index) ->
					values[index] = Object.keys(values[index]).length
				@lineChart logs, date, start, combine, reduce

			when "views"
				start = -> 0
				combine = (values, index, element) ->
					if element.type in ["connected", "location"]
						values[index]++
				reduce = ->
				@lineChart logs, date, start, combine, reduce

			when "logins"
				start = -> 0
				combine = (values, index, element) ->
					if element.type in ["login"]
						values[index]++
				reduce = ->
				@lineChart logs, date, start, combine, reduce

			when "logouts"
				start = -> 0
				combine = (values, index, element) ->
					if element.type in ["logout"]
						values[index]++
				reduce = ->
				@lineChart logs, date, start, combine, reduce

			when "uniquePages"
				start = -> {}
				combine = (values, index, element) ->
					if element.type in ["connected", "location"]
						values[index][element.location] = 1
				reduce = (values, index) ->
					values[index] = Object.keys(values[index]).length
				@lineChart logs, date, start, combine, reduce

			when "maxDevices"
				start = -> {}
				combine = (values, index, element) ->
					if element.userIdentifier
						if not values[index][element.userIdentifier]
							values[index][element.userIdentifier] = {}
						values[index][element.userIdentifier][element.device.id] = 1
				reduce = (values, index) ->
					max = 0
					for key, value of values[index]
						max = Math.max(max, Object.keys(value).length)
					values[index] = max
				@lineChart logs, date, start, combine, reduce

			when "browsers"
				key = (element) ->
					element.device.browser
				filter = (element) ->
					element.type in ["connected", "location"]
				@pieChart logs, key, filter

			when "browserVersions"
				key = (element) ->
					"#{element.device.browser} #{element.device.browserVersion}"
				filter = (element) ->
					element.type in ["connected", "location"]
				@pieChart logs, key, filter

			when "oses"
				key = (element) ->
					element.device.os
				filter = (element) ->
					element.type in ["connected", "location"]
				@pieChart logs, key, filter

			when "pages"
				key = (element) ->
					element.location
				filter = (element) ->
					element.type in ["connected", "location"]
				@pieChart logs, key, filter

	pieChart: (data, key, filter) ->
		i = 0
		buckets = {}
		while i < data.length
			k = key(data[i])
			if filter(data[i])
				if not buckets[k]
					buckets[k] = 1
				else
					buckets[k]++
			i++

		values = []
		for label, count of buckets

			color = [Math.floor(Math.random()*256), Math.floor(Math.random()*256), Math.floor(Math.random()*256)]

			lighten = 20

			highlight = [Math.min(color[0] + lighten, 255), Math.min(color[1] + lighten, 255), Math.min(color[2] + lighten, 255)]

			values.push
				value: count
				label: label
				color: "rgb(#{color[0]},#{color[1]},#{color[2]})"
				highlight: "rgb(#{highlight[0]},#{highlight[1]},#{highlight[2]})"

		values.sort (a, b) ->
			a.value <= b.value

		if @currentChart
			@currentChart.destroy()

		ctx = @timeline.getContext("2d")
		@chart = new Chart(ctx)
		@currentChart = @chart.Pie values

	getBuckets: (start) ->

		buckets = []
		values = []

		from = moment(@state.from)
		to = moment(@state.to)

		if to.diff(from, 'weeks') > 40
			granularity = 'month'
		else if to.diff(from, 'days') > 40
			granularity = 'week'
		else if to.diff(from, 'hours') > 40
			granularity = 'day'
		else
			granularity = 'hour'

		# Create buckets

		current = from.startOf(granularity)
		to = to.endOf(granularity)
		while current < to
			buckets.push moment(current)
			values.push start()
			current.add(1, granularity)

		formats =
			month: "MMMM"
			week: "w"
			day: "D"
			hour: "H"
		labels = (point.format(formats[granularity]) for point in buckets)
		buckets.push moment(current)

		[labels, buckets, values]
	lineChart: (data, date, start, combine, reduce) ->
		if not data
			return

		if not @timeline
			return

		[labels, buckets, values] = @getBuckets start

		i = 0
		# Discard all points earlier than buckets[0]
		while i < data.length
			current = moment(date(data[i]))
			if current >= buckets[0]
				break
			i++

		j = 1
		# Add al points to their respective buckets
		while i < data.length and j < buckets.length
			current = moment(date(data[i]))
			while current > buckets[j] and j < buckets.length
				j++

			if j >= buckets.length
				break

			combine(values, j-1, data[i])

			i++

		# Reduce the bucket values
		for value, i in values
			reduce(values, i)

		if @currentChart
			@currentChart.destroy()

		ctx = @timeline.getContext("2d")
		@chart = new Chart(ctx)
		@currentChart = @chart.Line
			labels: labels
			datasets: [
				label: "Logs"
				data: values
			]

	render: ->
		<div>
			<div className="col-xs-12">
				<h2>Timeline</h2>
			</div>
			<div className="col-xs-12 col-sm-6">
				<Templates.DateRangeInput id="range" label="Time range" from={@state.from} to={@state.to} onChange={@updateRange('from', 'to')}/>
			</div>
			<div className="col-xs-12 col-sm-6">
				<Templates.Select id="display" label="Data" options={@displays} value={@state.display} onChange={@updateValue('display')}/>
			</div>
			<div className="col-xs-12">
				<div id="timeline-wrapper">
					<canvas id="timeline"></canvas>
				</div>
			</div>
		</div>

Views.OldTimeline = React.createClass
	mixins: [ReactMeteorData, ReactUtils]
	getInitialState: ->
		from: moment().subtract(30, 'days').toDate()
		to: new Date()
	getMeteorData: ->
		find =
			appId: @props.appId

		if @state.from or @state.to
			find.loggedAt = {}
		if @state.from
			find.loggedAt.$gte = @state.from
		if @state.to
			find.loggedAt.$lte = @state.to

		logs = Logs.find find,
				sort:
					loggedAt: -1
			.fetch()

		@start logs

		logs: logs
	start: (logs) ->
		if not @chart
			return

		if not logs
			logs = @data.logs

		data =
			for l in logs
				date: l.loggedAt
				value: l.connectedDevices.length


		if data.length
			MG.data_graphic
				width: @wrapper.width()
				height: @wrapper.height()
				data: data
				#missing_is_hidden: true
				target: "#timeline"
				xax_start_at_min: true
				chart_type: "point"
				transition_on_update: true
		else
			MG.data_graphic
				width: @wrapper.width()
				height: @wrapper.height()
				data: data
				#missing_is_hidden: true
				target: "#timeline"
				xax_start_at_min: true
				chart_type: "missing-data"
				transition_on_update: true


		###
		data = ['Devices']
		for log in @data.logs
			data.push log.connectedDevices.length + 1
		@chart.load
			columns: [
				data
			]
		###
	componentDidMount: ->
		@chart = $('#timeline')
		@wrapper = $('#timeline-wrapper')

		$(window).resize @start

		###
		@chart = c3.generate
			bindto: '#timeline'
			data:
				columns: [
					['Devices']
				]
		###
		@start()
	render: ->
		<div className="col-xs-12">
			<h2>Timeline</h2>
			<Templates.DateRangeInput id="range" label="Range" from={@state.from} to={@state.to} onChange={@updateRange('from', 'to')}/>
			<div id="timeline-wrapper">
				<div id="timeline"></div>
			</div>
		</div>

Views.Devices = React.createClass
	render: ->
		<div className="col-xs-12">
			<h2>Devices</h2>
			{
				if @props.devices?.length
					<div>
						<DevicesGraph appId={@props.appId}/>
						<Templates.Table headers={["Id", "Browser", "Size", "Roles", "Connected devices", "Last updated"]}>
							{
								for device, i in @props.devices
									<tr key={i}>
										<td>{device.id}</td>
										<td>{device.browser} {device.browserVersion}</td>
										<td>
											{
												if device.width? or device.height?
													<span>{device.width}x{device.height}</span>
											}
											{
												if device.minWidth != device.maxWidth or device.minHeight != device.maxHeight
													<span>&nbsp;({device.minWidth}-{device.maxWidth}x{device.minHeight}-{device.maxHeight})</span>
											}
										</td>
										<td>
											{
												if device.roles?.length
													<ul>
														{
															for role, i in device.roles
																<li key={i}>{role}</li>
														}
													</ul>
											}
										</td>
										<td>
											{
												if device.connectedDevices?.length
													<ul>
														{
															for connectedDevice, i in device.connectedDevices
																<li key={i}>{connectedDevice}</li>
														}
													</ul>
											}
										</td>
										<td>
											{moment(device.lastUpdatedAt).format('YYYY-MM-DD HH:mm:ss')}
										</td>
									</tr>
							}
						</Templates.Table>
					</div>
				else
					<p>No devices were detected for this app yet.</p>
			}
		</div>

Views.Logs = React.createClass
	render: ->
		<div className="col-xs-12">
			<h2>Logs</h2>
			{
				if @props.logs?.length
					<Templates.Table headers={["Logged at", "Device ID", "Device", "User ID", "Location", "Type", "Comment"]}>
						{
							for l, i in @props.logs
								<tr key={i}>
									<td>{moment(l.loggedAt).format('YYYY-MM-DD HH:mm:ss:SSS')}</td>
									<td>{l.device.id}</td>
									<td>{l.device.os}, {l.device.browser} {l.device.browserVersion} ({l.device.width}x{l.device.height})</td>
									<td>{l.userIdentifier}</td>
									<td>{l.location}</td>
									<td>{l.type}</td>
									<td>{l.comment}</td>
								</tr>
						}
					</Templates.Table>
				else
					<p>There are no logs for this app yet.</p>
			}
		</div>

DevicesGraph = React.createClass
	mixins: [ReactMeteorData]
	getInitialState: ->
		role: null
	getMeteorData: ->
		devices = Devices.find
					appId: @props.appId
				,
					sort:
						lastUpdatedAt: -1
			.fetch()

		for node in devices
			found = false
			for node2 in @nodes
				if node2.id == node.id
					for key of node
						node2[key] = node[key]
					found = true
					break
			if not found
				@nodes.push(node)

		#TODO: what if a device has been removed? Indeces will be all wrong
		for device, i in devices
			if device.connectedDevices
				for cd in device.connectedDevices
					for device2, j in devices
						if device2.id == cd
							@links.push
								source: i
								target: j
								value: 1

		roles = {}
		for device in devices
			if device.roles
				for role in device.roles
					roles[role] = 1
			if device.connectedDevices
				for cd in device.connectedDevices
					if cd.roles
						for role in cd.roles
							roles[role] = 1

		@start()

		roles: roles
	width: 400
	height: 400
	nodes: []
	links: []
	node: null
	link: null
	ratio: 0.1
	start: ->
		if not @graph
			return

		if not @force
			@force = d3.layout.force()
				.nodes(@nodes)
				.links(@links)
				.charge(-800)
				.size([$(@graph[0]).width(), $(@graph[0]).height()])
				.linkDistance(120)
				.on("tick", @tick)


		@link = @link.data(@force.links())
		@link.enter().append("div")
			.attr("class", "link")

		@link.exit().remove()

		@node = @node.data(@force.nodes())
		n = @node.enter().append("div")
		n.attr("class", "node")
			.call(@force.drag)

		n.append("div")
			.attr("class", (d) -> "browser #{d.browser}")

		@node.exit().remove()

		@force.start()
	tick: ->
		self = @

		@node
			.attr("style", (d) ->
				style = "left: #{d.x - d.width*self.ratio/2}px; top: #{d.y - d.height*self.ratio/2}px; width: #{d.width*self.ratio}px; height: #{d.height*self.ratio}px;"
				if d.roles and self.state.role in d.roles
					style += "background-color: #72E66D; border: 1px solid #027D46;"
				style
			)

		@link.attr("style", (d) ->
			getLineStyle(d.source.x, d.source.y, d.target.x, d.target.y))
	componentDidMount: ->
		@graph = d3.select('#devicesGraph')
		@node = @graph.selectAll(".node")
		@link = @graph.selectAll(".link")

		@start()
	setRole: (role) ->
		self = @
		->
			self.setState
				role: role
			self.start()
	getRoleStyle: (role) ->
		if role is @state.role
			"backgroundColor": "#72E66D"
			color: "white"
		else
			{}
	render: ->
		<div>
			<div className="roles">
				<ul>
					{
						for role of @data.roles
								<li key={role} style={@getRoleStyle(role)}><a onClick={@setRole(role)} >{role}</a></li>
					}
				</ul>
				<div className="clearfix"></div>
			</div>
			<div id="devicesGraph" style={width: "100%", height: "400px"}></div>
		</div>


getLineStyle = (x1, y1, x2, y2) ->

	if (y1 < y2)
		pom = y1
		y1 = y2
		y2 = pom
		pom = x1
		x1 = x2
		x2 = pom

	a = Math.abs(x1-x2)
	b = Math.abs(y1-y2)
	c
	sx = (x1+x2)/2
	sy = (y1+y2)/2
	width = Math.sqrt(a*a + b*b )
	x = sx - width/2
	y = sy

	a = width / 2

	c = Math.abs(sx-x)

	b = Math.sqrt(Math.abs(x1-x)*Math.abs(x1-x)+Math.abs(y1-y)*Math.abs(y1-y) )

	cosb = (b*b - a*a - c*c) / (2*a*c)
	rad = Math.acos(cosb)
	deg = (rad*180)/Math.PI

	'width:'+width+'px;-moz-transform:rotate('+deg+'deg);-webkit-transform:rotate('+deg+'deg);top:'+y+'px;left:'+x+'px;'
