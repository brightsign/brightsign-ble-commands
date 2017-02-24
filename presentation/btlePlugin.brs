Function bluetooth_Initialize(msgPort As Object, userVariables As Object, bsp as Object)
	print "****************************************************************************"
    print "Bluetooth Plugin - Start"
 	print "****************************************************************************"

    bt = newBluetoothManager(msgPort, userVariables, bsp)

    return bt
End Function

Function newBluetoothManager(msgPort as Object, userVariables As Object, bsp as Object)
	bt = {}

	bt.version = "0.0.11"
	bt.objectName = "bluetooth"

	bt.appId$ = "001cff90"
	bt.txPower = -52

	bt.mgr = CreateObject("roBtClientManager")
	bt.msgPort = msgPort
	bt.mgr.SetPort(msgPort)

	bt.clientParams = {}
	bt.clientParams.service_uuid = "99A80B03-E9F7-4B19-B6B5-4FD18B22DC42"
	bt.clientParams.clientid_uuid = "152013eb-406f-4598-8590-a86f76cb535c"
	bt.clientParams.user_variable_uuid = "cf2186ff-e140-47b5-a18d-0b2ec79f8b98"
	bt.clientParams.command_uuid = "3c0a1e45-4677-4f6e-8cbc-98e190840d30"
	bt.clientParams.device_info_uuid = "a2011df6-1241-482f-99d5-a2d635a32436"
	bt.clientParams.device_data_uuid = "90b9776a-bc0f-4b35-8135-1848bc5eab1b"
	bt.clientParams.client_timeout = 30

	bt.userVariables = userVariables
	bt.bsp = bsp
	bt.ProcessEvent = bt_ProcessEvent
	bt.NewClient = bt_NewClient
	bt.SendPluginEvent = bt_SendPluginEvent
	bt.GetTimeStampString = bt_GetTimeStampString

	bt.activeClients = {}

	bt.monitorTimer = CreateObject("roTimer")
	bt.monitorTimer.SetPort(bt.msgPort)
	bt.monitorTimer.SetElapsed(1, 0)
	bt.monitorTimer.Start()

	print "Bluetooth Plugin - Init Complete"	
	return bt
End Function

Function bt_ProcessEvent(event As Object) as Boolean
	print "Received event type: ";type(event)
	retval = false
	if type(event) = "roBtClientManagerEvent" then
		eventName = event.GetEvent()
		roClient = event.GetClient()
		roClientId = roClient.GetClientId()
		if eventName = "client-new" then
			if not m.activeClients.DoesExist(roClientId) then
				print "BTLE Client added, id = ";roClientId
				m.activeClients[roClientId] = m.NewClient(roClient)
			endif
			m.activeClients[roClientId].activeSession = true
			' Set busy flag
			print "Client added; setting busy"
			m.bsp.btManager.SetBtleStatus(1)
		else if eventName= "client-delete" then
			btClient = m.activeClients[roClientId]
			if btClient <> invalid then
				deletedClientActive = btClient.activeSession
				m.activeClients.Delete(roClientId)
				print "BTLE Client deleted, id = ";roClientId
				' delete temp zone, send message, etc.
				' If session was active, reset busy flag
				if deletedClientActive then
					print "Active client deleted; resetting busy"
					m.bsp.btManager.SetBtleStatus(0)
				endif
			endif
		endif
		retval = true
	else if type(event) = "roBtClientEvent" then
		roClientId = event.GetUserData()
		if IsString(roClientId) then
			btClient = m.activeClients[roClientId]
			if btClient <> invalid then
				eventName = event.GetEvent()
				if eventName = "client-update" then
					if not btClient.activeSession then
						btClient.activeSession = true
						print "Client session activated; setting busy"
						m.bsp.btManager.SetBtleStatus(1)
					endif
					btClient.GetNewClientUserData()
					print "BTLE Client user data updated: ";btClient.clientData
				else if eventName= "client-command" then
					command = event.GetParam()
					if IsString(command) then
						ts$ = m.GetTimeStampString()
						print ts$;" received command: ";command
						if command = "__disconnect" then
							btClient.roClient.Disconnect()
						else if command = "__close" then
							m.SendPluginEvent("Home")
							if btClient.activeSession then
								print "Session close notification received; resetting busy"
								btClient.activeSession = false
								m.bsp.btManager.SetBtleStatus(0)
							endif
							' Force disconnect after close
							btClient.roClient.Disconnect()
						else
							m.SendPluginEvent(command)
							' Also send as UDP message
							'm.SendUDPMessage(command)
						endif
					endif
				endif
			endif
		endif
		retval = true
	else if type(event) = "roTimerEvent" then
		if type(m.monitorTimer) = "roTimer" and event.GetSourceIdentity() = m.monitorTimer.GetIdentity() then
			print "Starting BTLE client with:"
			print m.clientParams
			m.bsp.btManager.StartBtleClient(m.clientParams, m.appId$, m.txPower)

			if type(m.bsp.btManager.btleClientManager) = "roBtClientManager" then
				m.bsp.btManager.btleClientManager.SetDeviceInfo(FormatJson({appId: m.appId$}))
				jsonFilePath$ = GetPoolFilePath(m.bsp.assetPoolFiles, "commands.json")
				cmds = GetCommands(jsonFilePath$)
				cmds$ = FormatJson({cm: cmds})
				print cmds$
				m.bsp.btManager.btleClientManager.SetDeviceData(cmds$)
			else
				print "-x-x-x - Could not create BtClientManager - check firmware version - must be 6.2.94 or higher"
			endif
			retval = true
		endif
	endif
	return retval
End Function

Function bt_NewClient(roClient as Object) as Object
	intClient = {}
	intClient.roClient = roClient
	intClient.clientData = {}
	intClient.activeSession = false

	' Set client ID to UserData
	roClient.SetUserData(roClient.GetClientId())
	roClient.SetPort(m.msgPort)

	' Initialize the UserVar string
	roClient.SetUserVars(FormatJson(intClient.clientData))

	intClient.GetNewClientUserData = roc_GetNewClientUserData

	return intClient
End Function

Function GetCommands(jsonFilePath$ as string) as Object
	if (jsonFilePath$ = invalid or jsonFilePath$ = "") then
		print "-x-x-x - commands.json file not found"
		commands = []
	else
		cmdText$ = ReadAsciiFile(jsonFilePath$)
		commands = ParseJson(cmdText$)
		if type(commands) <> "roArray" then
			commands = []
		endif
		print "---- Commands (";commands.Count();" ):"
		print commands
	endif
	return commands
End Function

Sub roc_GetNewClientUserData()
	data = ParseJson(m.roClient.GetUserVars())
	if type(data) = "roAssociativeArray" then
		m.clientData = data
	else
		m.clientData = {}
	endif
End Sub

Sub bt_SendPluginEvent(message as string)
	pluginMessageCmd = CreateObject("roAssociativeArray")
	pluginMessageCmd["EventType"] = "EVENT_PLUGIN_MESSAGE"
	pluginMessageCmd["PluginName"] = m.objectName
	pluginMessageCmd["PluginMessage"] = message
	m.msgPort.PostMessage(pluginMessageCmd)
End Sub

Function bt_GetTimeStampString() as String
	time = m.bsp.systemTime.GetLocalDateTime()
	str$ = time.GetString()
	return "[" + str$.Right(12).Left(8) + "]"
End Function
