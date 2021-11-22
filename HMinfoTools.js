FW_version["HMinfoTools.js"] = "$Id: HMinfoTools.js 2001 2021-11-22 18:00:00Z frank $";

var HMinfoTools_debug = true;
var HMinfoTools_csrf;
var devMap = new Map();
var HMinfoTools_icons = [
	{name: 'commState',poll: 'parent',svg: 'rc_dot',colorElements: ['path'],clickG: 'clearG msgErrors',click: 'HMinfoTools_setClearMsgEvents'},
	{name: 'rssi',poll: 'parent',svg: 'it_wifi',colorElements: ['g'],clickG: 'clearG rssi',click: 'HMinfoTools_setClearRssi'},
	{name: 'IODev',poll: 'parent',svg: 'cul_868',colorElements: ['g'],clickG: '',click: ''},
	{name: 'cfgState',poll: 'device',svg: 'edit_settings',colorElements: ['g'],clickG: '',click: 'HMinfoTools_setGetConfig'},
	{name: 'Activity',poll: 'parent',svg: 'message_attention',colorElements: ['path'],clickG: 'cmdRequestG ping',click: ''},
	{name: 'battery',poll: 'parent',svg: 'measure_battery_75',colorElements: ['g'],clickG: '',click: 'HMinfoTools_setBatteryChange'},
	{name: 'motorErr',poll: 'device',svg: 'sani_domestic_waterworks',colorElements: ['g'],clickG: '',click: ''},
	{name: 'sabotageError',poll: 'device',svg: 'secur_locked',colorElements: ['g'],clickG: '',click: ''},
	{name: 'sabotageAttack',poll: 'parent',svg: 'ring',colorElements: ['polygon','path','rect'],clickG: 'clearG attack',click: 'HMinfoTools_setClearAttack'},
	{name: 'smokeDetect',poll: 'device',svg: 'secur_smoke_detector',colorElements: ['g'],clickG: '',click: ''}
];

$(document).ready(function() {
	var body = document.querySelector('body');
	if(body != null) {HMinfoTools_csrf = body.getAttribute('fwcsrf');}
	var seldiv = document.querySelector('div.makeSelect'); 
	var weblinkdiv = document.getElementById('hminfotools_weblink'); 
	if(seldiv != null) {
		var hminfo = seldiv.getAttribute('dev');
		HMinfoTools_parseErrorDevices(hminfo,weblinkdiv);
	}
	else if(weblinkdiv != null) {
		var hminfo = weblinkdiv.getAttribute('dev');
		HMinfoTools_parseErrorDevices(hminfo,weblinkdiv);
	}
});

function HMinfoTools_initMapDevice(device) {
	var devObj = {name: device, 
								parentDev: '', 
								errors: [], 
								model: '',
								commState: '',
								rssi: '',
								IODev: '',
								aIODev: '',
								IOgrp: '',
								cfgState: '',
								actCycle: '',
								actStatus: '',
								activity: '',
								battery: '',
								motorErr: '',
								sabotageError: '',
								sabotageAttack: '',
								smokeDetect: ''
	};
	devMap.set(device,devObj);
}

function HMinfoTools_parseDevFromJson(device,data) {
	var devObj = devMap.get(device);
	//parentDev
	devObj.parentDev = (data.Internals.DEF.length == 6)? data.Internals.NAME: data.Internals.device;
	//model
	devObj.model = (data.Attributes.model != null)? data.Attributes.model: 'missing_model';
	//commState
	devObj.commState = (data.Readings.commState != null)? data.Readings.commState.Value: 'Info_Unknown';
	//rssi
	internalsString = JSON.stringify(data.Internals);
	var curIoDev = (data.Internals.IODev != null && !data.Internals.IODev.match(/^HASH\(/))
										? data.Internals.IODev
										: 'missing_IODev';
	devObj.rssi = 'rssi_at_'+curIoDev+' => ' + ((internalsString.match('rssi_at_'+curIoDev))
																								? data.Internals['rssi_at_'+curIoDev]
																								: 'missing_rssi');
	//IODev
	if(data.Internals.IODev != null) {devObj.IODev = (data.Internals.IODev != null)? data.Internals.IODev: 'missing_IODev';}
	//aIODev
	devObj.aIODev = (data.Attributes.aIODev != null)? data.Attributes.aIODev: 'missing_aIODev';
	//IOgrp
	devObj.IOgrp = (data.Attributes.IOgrp != null)? data.Attributes.IOgrp: 'missing_IOgrp';
	//cfgState
	devObj.cfgState = (data.Readings.cfgState != null)? data.Readings.cfgState.Value: 'Info_Unknown';
	//actCycle
	devObj.actCycle = (data.Attributes.actCycle != null)? data.Attributes.actCycle: 'unknown';
	//actStatus
	devObj.actStatus = (data.Attributes.actStatus != null)? data.Attributes.actStatus: 'unknown';
	//actionDetector
	if(data.Attributes.actCycle != null) {
		if(data.Attributes.actCycle == '000:00') {devObj.activity = 'switchedOff';}
		else {devObj.activity = (data.Attributes.actStatus != null)? data.Attributes.actStatus: 'unknown';}
	}
	else {devObj.activity = 'unused';}
	//battery
	if(data.Readings.battery != null) {devObj.battery = data.Readings.battery.Value;}
	//motorErr
	if(data.Readings.motorErr != null) {devObj.motorErr = data.Readings.motorErr.Value;}
	//sabotage
	if(data.Readings.sabotageError != null) {devObj.sabotageError = data.Readings.sabotageError.Value;}
	//attack
	if(data.Readings.sabotageAttack_ErrIoAttack_cnt != null) {devObj.sabotageAttack = data.Readings.sabotageAttack_ErrIoAttack_cnt.Value;}
	//smokeDetect
	if(data.Readings.smoke_detect != null) {devObj.smokeDetect = data.Readings.smoke_detect.Value;}
	
	devMap.set(device,devObj);
}

function HMinfoTools_parseErrorDevices(hminfo,weblinkdiv) {
	var cmd = 'jsonlist2 ' + hminfo;
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.getJSON(url).done(function(data) {
		var object = data.Results[0];
		if(object != null && object.Internals.TYPE == 'CUL_HM' && object.Attributes.model != 'ACTIONDETECTOR') {
			if(typeof HMdeviceTools_createRegisterTable == 'function') { //for cul_hm device details (hm.js)
				if(HMinfoTools_debug) {log('HMinfoTools: ' + 'HMdeviceTools is present');}
				var isHMdeviceTools = false;
				var isHMdeviceTools_pendingInfo = false;
			
				//install mutationObserver to manage perfect handling
				const observer3 = new MutationObserver(function(mutationList,observer) {
					mutationList.forEach((mutation) => {
						if(mutation.type == 'attributes' && mutation.target == document.getElementById('HMdeviceTools_toolsTable')){

							if(mutation.attributeName == 'installation') {
								if(mutation.oldValue == null) { //value=init
									if(HMinfoTools_debug) {log('HMinfoTools: ' + 'HMdeviceTools => started installation');}
								}
								else if(mutation.oldValue == 'init') { //value=ready
									isHMdeviceTools = true;
									if(HMinfoTools_debug) {log('HMinfoTools: ' + 'HMdeviceTools => finished installation');}
									HMinfoTools_loadIcons(object.Internals.NAME,document.getElementById('HMdeviceTools_toolsTable_svg'));
									$('#HMdeviceTools_toolsTable').attr('errordevices_data','start'); //1. run (allready done)
									$('#HMdeviceTools_toolsTable').attr('errordevices_data','first'); //1. run (allready done)
									$('#HMdeviceTools_toolsTable').attr('errordevices_list',object.Internals.NAME);
									if(isHMdeviceTools_pendingInfo && object.Internals.DEF.length == 8) {
										$('#HMdeviceTools_toolsTable').attr('errordevices_list',(object.Internals.NAME+':'+data.Results[0].Internals.NAME));
										$('#HMdeviceTools_toolsTable').attr('errordevices_data','ready'); //2. run (allready done)
									}
									else if(object.Internals.DEF.length == 6) {
										$('#HMdeviceTools_toolsTable').attr('errordevices_data','ready'); //only 1. run (allready done)
									}
								}
							}				
						
							var isInstallationReady = ($('#HMdeviceTools_toolsTable').attr('installation') == 'ready')? true: false;
							var areIconsLoaded = ($('#HMdeviceTools_toolsTable').attr('loaded_icons') == HMinfoTools_icons.length)? true: false;
							//var isErrDataFirst = ($('#HMdeviceTools_toolsTable').attr('errordevices_data') == 'first')? true: false;
							var isErrDataReady = ($('#HMdeviceTools_toolsTable').attr('errordevices_data') == 'ready')? true: false;
							
							if(isInstallationReady && areIconsLoaded && isErrDataReady) { //all icons and infos loaded
								observer3.disconnect();
								var errorList = $('#HMdeviceTools_toolsTable').attr('errordevices_list');
								var errorDevices = errorList.split(':')[0];
								if(errorDevices != '') {
									if(HMinfoTools_debug) {log('HMinfoTools: ' + 'HMdeviceTools => all data ready');}
									HMinfoTools_createIconCells(document.getElementById('HMdeviceTools_toolsTable_icons'),object.Internals.NAME); 
									HMinfoTools_initIcons(object.Internals.NAME); 
									var informDevices = (errorList.match(/:$/))? errorList.replace(/:$/,''): errorList.replace(/:/,',');
									setTimeout(HMinfoTools_changeInformChannel(informDevices),1000);
								}
							}
						}
					});
				});
				observer3.observe(document.body,{subtree: true,
																				 childList: false,
																				 attributeFilter: ['installation','loaded_icons','errordevices_data'],
																				 attributeOldValue: true}
				);

				HMinfoTools_initMapDevice(object.Internals.NAME);
				HMinfoTools_parseDevFromJson(object.Internals.NAME,object);
				if(object.Internals.DEF.length == 8) {
					var cmd = 'jsonlist2 ' + object.Internals.device;
					if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
					var url = HMinfoTools_makeCommand(cmd);
					$.getJSON(url,function(data) {
						if(data.Results[0] != null) {
							HMinfoTools_initMapDevice(data.Results[0].Internals.NAME);
							HMinfoTools_parseDevFromJson(data.Results[0].Internals.NAME,data.Results[0]);
							if(isHMdeviceTools) {
								$('#HMdeviceTools_toolsTable').attr('errordevices_list',(object.Internals.NAME+':'+data.Results[0].Internals.NAME));
								$('#HMdeviceTools_toolsTable').attr('errordevices_data','ready'); //2. run (allready done)
							}
							else {isHMdeviceTools_pendingInfo = true;}
						}
					});
				}
				if(document.getElementById('HMdeviceTools_toolsTable') != null && $('#HMdeviceTools_toolsTable').attr('installation') == 'ready') {
					isHMdeviceTools = true;
					if(HMinfoTools_debug) {log('HMinfoTools: ' + 'HMdeviceTools => is ready');}
					HMinfoTools_loadIcons(hminfo,document.getElementById('HMdeviceTools_toolsTable_svg'));
					$('#HMdeviceTools_toolsTable').attr('errordevices_data','start'); //1. run (allready done)
					$('#HMdeviceTools_toolsTable').attr('errordevices_data','first'); //1. run (allready done)
					$('#HMdeviceTools_toolsTable').attr('errordevices_list',object.Internals.NAME); //1. run (allready done)
					if(object.Internals.DEF.length == 6) {
						$('#HMdeviceTools_toolsTable').attr('errordevices_data','ready'); //only 1. run (allready done)
					}
				}
				else {
				}
			}
		}

		else if(object != null && object.Internals.TYPE == 'HMinfo') { //for hminfo details/weblink
			if(document.getElementById('hminfotools') == null) { // 1. run, we want to install basic things
				var lastChange = ((object.Readings.lastErrChange == null)? 
													'updated: Info_Unknown': object.Readings.lastErrChange.Value);
				HMinfoTools_createHMinfoTools(hminfo,weblinkdiv,lastChange);
				$('#hminfotools').attr('device_mode',((object.Attributes.HMinfoTools_deviceMode == null)
																								? 'err'
																								: object.Attributes.HMinfoTools_deviceMode));;
				var ssAttr = ((object.Attributes.HMinfoTools_screenshotPort == null)? 
													'': object.Attributes.HMinfoTools_screenshotPort);
				var ssArgs = ssAttr.split(',');
				$('#hminfotools').attr('ss_port',((ssArgs[0] != null)? ssArgs[0]: ''));
				$('#hminfotools').attr('ss_room',((ssArgs[1] != null)? ssArgs[1]: ''));
			}
			HMinfoTools_parseIOsFromHMinfo(object.Internals.iI_HM_IOdevices);
			
			/*search for devices with errors: CRI_, ERR_, W_
			"iCRI__protocol":"SwitchPBU06",
			"iERR___rssiCrit":"Thermostat.Keller",
			"iERR__actDead":"SwitchUP01",
			"iERR__protocol":"Ventil.AZ.Nord,Ventil.AZ.West,Ventil.Bad,Ventil.Kueche,Ventil.WZ",
			"iERR_battery":"Thermostat.WZ",
			"iERR_sabotageError":"Tuer.SZ",
			"iW__protoNames":"DimUP01",
			"iW__unreachNames":"DimPBU01_Sw1_V01,DimPBU01_Sw1_V02,SwitchPBU01_Sw_02"
			*/
			var errorDevices = '';
			var internalsString = JSON.stringify(object.Internals);
			var mErrorInternal = internalsString.match(/i(?:CRI_|ERR_|W_)[^"]+/g);
			if(mErrorInternal != null) {
				for(var i = 0; i < mErrorInternal.length; ++i) {
					if(object.Internals[mErrorInternal[i]] != undefined) {
						var devices = object.Internals[mErrorInternal[i]].split(','); 
						for(var d = 0; d < devices.length; ++d) {
							var devObj = {};
							if(!devMap.has(devices[d])) {
								errorDevices += devices[d] +',';
								HMinfoTools_initMapDevice(devices[d]);
								devObj = devMap.get(devices[d]);
								devObj.errors = [mErrorInternal[i]];
							}
							else {
								devObj = devMap.get(devices[d]);
								devObj.errors.push(mErrorInternal[i]);
							}
							devMap.set(devices[d],devObj);
						}
					}
				}
			}

			if($('#hminfotools').attr('device_mode') == 'all') { //all devices w/o problems
				var cmd = 'list TYPE=CUL_HM:FILTER=DEF=......:FILTER=DEF!=000000 i:NAME';
				if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
				var url = HMinfoTools_makeCommand(cmd);
				$.get(url,function(data) {
					if(data != null) {
						//SwitchES01               SwitchES01
						var deviceList = '';
						var lines = data.split('\n');
						for(var l = 0; l < lines.length; ++l) {
							if(lines[l] != '') {
								var device = lines[l].match(/[^\s]+$/)[0];
								deviceList += device + ',';
								if(!devMap.has(device)) {
									errorDevices += device + ',';
									HMinfoTools_initMapDevice(device);
								}
							}
						}
						deviceList = deviceList.replace(/,$/,'');
						$('#hminfotools').attr('alldevices_list',deviceList);
						errorDevices = errorDevices.replace(/,$/,'');
						$('#hminfotools').attr('errordevices_list',errorDevices);
						if(errorDevices != '') {
							$('#hminfotools').attr('errordevices_data','start');
							HMinfoTools_getInfoFromErrorDevices('hminfotools'); //1. run (mode=allDevices)
						}
						else {
							$('#hminfotools').attr('errordevices_data','ready');
							HMinfoTools_changeInformChannel('');
							document.getElementById('hminfo_info').innerHTML = ' => waiting for problems...';
						}
					}
				});
			}
			else { //only devices with problems
				errorDevices = errorDevices.replace(/,$/,'');
				$('#hminfotools').attr('errordevices_list',errorDevices);
				if(errorDevices != '') {
					$('#hminfotools').attr('errordevices_data','start');
					HMinfoTools_getInfoFromErrorDevices('hminfotools'); //1. run (mode=errDevices)
				}
				else {
					$('#hminfotools').attr('errordevices_data','ready');
					HMinfoTools_changeInformChannel('');
					document.getElementById('hminfo_info').innerHTML = ' => waiting for problems...';
				}
			}
			
			
		}
	})
	.fail(function(xhr,status,err) {
		if(xhr.status == 400 && typeof HMinfoTools_csrf != 'undefined') {
			HMinfoTools_csrf = '';
			location.reload();
		}
	});
}

function HMinfoTools_createHMinfoTools(hminfo,weblinkdiv,lastChange) {
	var div = document.createElement('div');
	if(weblinkdiv == null) {
		// we will insert the table before the internals
		var intdiv = document.querySelector('div.makeTable.wide.internals');
		intdiv.parentElement.insertBefore(div,intdiv);
	}
	else {weblinkdiv.appendChild(div);}
	div.id = 'hminfotools';
	div.setAttribute('device',hminfo);            //name of hminfo device
	
	div.setAttribute('installation','init');      // init, ready
	div.setAttribute('loaded_icons','init');      // 0_icons: "init"; 9_icons: "9"
	div.setAttribute('errordevices_data','init'); // init, start, first, ready
	div.setAttribute('errordevices_list','init'); // list of current errorDevices
	div.setAttribute('lost','0');                 // list of lost connections
	
	//div.setAttribute('class','makeTable wide');
	div.setAttribute('class','makeTable wide internals');
	var header = document.createElement('span');
	div.appendChild(header);
	//header.setAttribute('class','col_header pinHeader');
	header.setAttribute('class','mkTitle');
	header.innerHTML = '<a href="/fhem?detail=' +hminfo+ '">HMinfoTools</a>';
	
	const elementToObserve = div;
	const observer1 = new MutationObserver(function(mutationList,observer) {
		mutationList.forEach((mutation) => {
			if(mutation.type == 'attributes'){
				var isInstallationReady = ($('#hminfotools').attr('installation') == 'ready')? true: false;
				var areIconsLoaded = ($('#hminfotools').attr('loaded_icons') == HMinfoTools_icons.length)? true: false;
				var isErrDataFirst = ($('#hminfotools').attr('errordevices_data') == 'first')? true: false;
				var isErrDataReady = ($('#hminfotools').attr('errordevices_data') == 'ready')? true: false;
				
				if(isErrDataFirst) {HMinfoTools_getInfoFromErrorDevices('hminfotools');} //2. run
				
				if(isInstallationReady && areIconsLoaded && isErrDataReady) { //all icons and infos loaded
					var errorList = $('#hminfotools').attr('errordevices_list');
					var errorDevices = errorList.split(':')[0];
					if(errorDevices != '') {
						if(HMinfoTools_debug) {log('HMinfoTools: ' + 'all data ready, new table creation!');}
						HMinfoTools_createErrorDevicesTable(errorDevices);
						var informDevices = (errorList.match(/:$/))? errorList.replace(/:$/,''): errorList.replace(/:/,',');
						setTimeout(HMinfoTools_changeInformChannel(informDevices),1000);
						if(typeof html2canvas == 'function') {
							var curPort = location.port;
							var ssPort = $('#hminfotools').attr('ss_port');
							var curRoom = ($('div#content').attr('room') == undefined)? '': $('div#content').attr('room');
							var ssRoom = $('#hminfotools').attr('ss_room');
							if(curPort == ssPort && curRoom == ssRoom) {
								if(HMinfoTools_debug) {log('HMinfoTools: ' + 'sreenshot');}
								//connection-lost-dead-loop, wenn ss_port=8083 vom pc browser
								//scheinbar verzögert setTimeout hier die initialisierung des longpoll websocket!!!
								setTimeout(HMinfoTools_createScreenshot(),10000);
							}
						}
					}
					else {if(HMinfoTools_debug) {log('HMinfoTools: ' + 'all data ready, no table creation!');}}
				}
			}
		});
	});	
	observer1.observe(div,{attributeFilter: ['installation','loaded_icons','errordevices_data']});
	
	const observer2 = new MutationObserver(function(mutationList,observer) {
		mutationList.forEach((mutation) => {
			if(mutation.type == 'childList' && mutation.addedNodes.length > 0) {
				var errmsg = document.getElementById('errmsg');
				//10:27:38.598 ERRMSG:Connection lost, trying a reconnect every 5 seconds.<
				if(errmsg != null && errmsg.innerHTML == 'Connection lost, trying a reconnect every 5 seconds.') {
					var lost = parseInt($('#hminfotools').attr('lost'));
					if(HMinfoTools_debug) {log('HMinfoTools: ' + '"Connection lost" detected! ('+lost+')');}
					if(lost > 5) {
						if(HMinfoTools_debug) {log('HMinfoTools: ' + 'close and open informchannel');}
						$('#hminfotools').attr('lost','0');
						location.reload(true);
					}
					else {$('#hminfotools').attr('lost',lost+1);}
				}
			}
		});
	});
	observer2.observe(document.body,{subtree: false,childList: true,attributes: false});

	var info = document.createElement('span');
	div.appendChild(info);
	info.id = 'hminfo_info';
	info.setAttribute('class','mkTitle');
	info.innerHTML = ' => waiting for problems...';
	var table = document.createElement('table');
	div.appendChild(table);
	table.id = 'devicetable';
	//table.setAttribute('class','block wide internals wrapcolumns');
	table.setAttribute('class','block wide internals');
	var thead = document.createElement('thead');
	table.appendChild(thead);
	var tr = document.createElement('tr');
	thead.appendChild(tr);
	tr.setAttribute('class','odd');
	var icons = document.createElement('td');
	tr.appendChild(icons);
	icons.style.whiteSpace = 'nowrap';
	HMinfoTools_loadIcons(hminfo,icons); //################################################################
	var td = document.createElement('td');
	tr.appendChild(td);
	var ios = document.createElement('span');
	td.appendChild(ios);
	ios.id = 'hminfo_ios';
	var td = document.createElement('td');
	tr.appendChild(td);
	var left = document.createElement('td');
	td.appendChild(left);
	var change = document.createElement('span');
	left.appendChild(change);
	change.id = 'hminfo_change';
	change.innerHTML = lastChange;
	
	var right = document.createElement('td');
	td.appendChild(right);
	right.align = 'right';
	var edit = document.createElement('span');
	right.appendChild(edit);
	edit.id = 'hminfo_edit';
	edit.title = 'under construction';
	//edit.setAttribute('onclick',"HMinfoTools_rssiCheck('"+hminfo+"')");

	var cmd = "{FW_makeImage('rc_SETUP')}";
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.ajax({
		url: url,
		type: "GET",
		context: edit,
		success: function(data){
			if(data) {
				this.innerHTML = data;
				$('#' +this.id+ ' svg').css('height','20px');
				$('#' +this.id+ ' svg').css('width','20px');
			}
		}
	});
	
	var tbody = document.createElement('tbody');
	table.appendChild(tbody);
	tbody.id = 'hminfo_table_errDev';

	$('#hminfotools').attr('installation','ready');
}

function HMinfoTools_parseIOsFromHMinfo(ioInfoRaw) {
	var vcculist = '';
	var iolist = '';
	var ioInfo = ioInfoRaw;
	
	if(ioInfoRaw != null && !ioInfoRaw.match(/>/)) { //old hminfo version
	  //iI_HM_IOdevices     Initialized: cul868;disconnected: hmuart1;dummy: hmusb1;ok: hmlan1;
		var ios = ioInfoRaw.match(/\s[^;]+/g);
		ios.forEach(function(io,idx,arr) {arr[idx] = io.trim();});
		iolist = ios.join(',');
		ios = iolist.split(',');
		ios.forEach(function(io) {
			var color = (ioInfoRaw.match('(?:Initialized|ok):\\s[^;]*'+io+'[^;]*;'))? 'lime': 'red';
			ioInfo = ioInfo.replace(io,'<a href="/fhem?detail='+io+'" style="color: '+color+';">'+io+'</a>');
		});
	}
	else if(ioInfoRaw != null && ioInfoRaw.match(/>/)) { //new hminfo version
		//iI_HM_IOdevices     ccu>Initialized:cul868;ok:hmlan1,hmuart1; noVccu>dummy:hmusb2; vccu2>dummy:hmusb1;
		var vccus = ioInfoRaw.match(/(?<=^|\s)[^>]+/g);

		var tmpVccuRawArr = ioInfoRaw.split(' ');
		tmpVccuRawArr.forEach(function(vccuStr) {
			var vccu = vccuStr.match(/(?<=^|\s)[^>]+/g);
			var vccuIOs = vccuStr.match(/(?<=:|,)[^,;]+/g);
			if(vccu != 'noVccu') {
				vcculist += (vcculist == '')? vccu+':'+vccuIOs.join(','): ' '+vccu+':'+vccuIOs.join(',');
			}
		});

		var ios = ioInfoRaw.match(/(?<=:|,)[^,;]+/g);
		iolist = ios.join(',');
		vccus.forEach(function(vccu) {
			var color = 'lightblue';
			if(vccu == 'noVccu') {ioInfo = ioInfo.replace(vccu,'<a style="color: '+color+';">'+vccu+'</a>');}
			else {ioInfo = ioInfo.replace(vccu,'<a href="/fhem?detail='+vccu+'" style="color: '+color+';">'+vccu+'</a>');}
		});
		ios.forEach(function(io) {
			var color = (ioInfoRaw.match('(?:Initialized|ok):[^;]*'+io+'[^;]*;'))? 'lime': 'red';
			ioInfo = ioInfo.replace(io,'<a href="/fhem?detail='+io+'" style="color: '+color+';">'+io+'</a>');
		});
	}
	else {ioInfo = 'IO_Devices: Info_Unknown';} //from fhem-restart until first hminfo-update
	$('#hminfotools').attr('vcculist',vcculist);
	$('#hminfotools').attr('iolist',iolist);
	document.getElementById('hminfo_ios').innerHTML = ioInfo;

}

function HMinfoTools_getInfoFromErrorDevices(idStr) {
	var deviceList;
	var isFirstRun = ($('#'+idStr).attr('errordevices_data') == 'start')? true: false;
	if(isFirstRun) {
		if(HMinfoTools_debug) {log('HMinfoTools: get data, 1. run');}
		deviceList = document.getElementById(idStr).getAttribute('errordevices_list');
	}
	else {
		if(HMinfoTools_debug) {log('HMinfoTools: get data, 2. run');}
		deviceList = document.getElementById(idStr).getAttribute('errordevices_list').split(':')[1];
		if(deviceList != '') {
			devices = deviceList.split(',');
			for(var d = 0; d < devices.length; ++d) {
				HMinfoTools_initMapDevice(devices[d]);
				var newObj = devMap.get(devices[d]);
				newObj.parentDev = devices[d];
				devMap.set(devices[d],newObj);
			}
		}
		else {
			$('#'+idStr).attr('errordevices_data','ready');
			return;
		}
	}
	
	//var ios = document.getElementById('hminfotools').getAttribute('iolist').split(',');
	//var test2 = Array.from(devMap.values());
	var iolist = document.getElementById(idStr).getAttribute('iolist');
	var ios = iolist.split(',');
	var cmd = 'list ' +deviceList+ ' i:DEF i:device ';
	cmd += 'a:model ';
	cmd += 'r:commState ';
	cmd += 'r:sabotageAttack_ErrIoAttack_cnt ';
	cmd += 'a:actCycle a:actStatus ';
	cmd += 'r:sabotageError ';
	cmd += 'i:IODev ';
	for(var i = 0; i < ios.length; ++i) {cmd += 'i:rssi_at_' +ios[i]+ ' ';}
	cmd += 'a:IOgrp ';
	cmd += 'a:IODev ';
	cmd += 'r:battery ';
	cmd += 'r:motorErr ';
	cmd += 'r:smoke_detect ';
	cmd += 'r:cfgState ';
	cmd += 'i:NAME';
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data != null) {
			/*
			HM_196BD8                                  DEF             196BD8
																								 model           HM-SEC-RHS
													 2021-03-17 18:10:43   commState       Info_Cleared
													 2021-02-21 19:54:41   sabotageError   on
																								 IODev           cul868
													 2021-02-21 19:54:41   battery         ok
													 2021-03-18 20:14:41   cfgState        PeerIncom,RegMiss
																								 NAME            HM_196BD8
			*/
			var informDevices = deviceList + ',';
			var devObj = {};
			var lines = data.split('\n');
			for(var l = 0; l < lines.length; ++l) {
				var deviceEnd = false;
				var line = lines[l];
				if(line.match(/\sDEF\s/)) {
					var device = line.match(/^[^\s]+/)[0];
					devObj = devMap.get(device);
					devObj.name = device;
					if(line.match(/[^\s]+$/)[0].length == 6) {devObj.parentDev = devObj.name;}
				}
				else if(line.match(/\sdevice\s/)) {devObj.parentDev = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\smodel\s/)) {devObj.model = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\scommState\s/)) {devObj.commState = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\ssabotageAttack_ErrIoAttack_cnt\s/)) {devObj.sabotageAttack = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\sactCycle\s/)) {devObj.actCycle = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\sactStatus\s/)) {devObj.actStatus = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\ssabotageError\s/)) {devObj.sabotageError = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\sIODev\s/)) {
					if(devObj.IODev == '') {devObj.IODev = line.match(/[^\s]*$/)[0];}
					else {devObj.aIODev = line.match(/[^\s]*$/)[0];}
				}
				else if(line.match(/\sIOgrp\s/)) {devObj.IOgrp = line.match(/[^\s]*$/)[0];}
				else if(line.match('\\srssi_at_' +devObj.IODev+ '\\s')) {devObj.rssi = line.match(/cnt:.+$/)[0];}
				else if(line.match(/\sbattery\s/)) {devObj.battery = line.match(/[^\s]*$/)[0];}
				//								 2021-01-06 14:42:48   motorErr        adjusting range too small  //err: parse only "small"
				else if(line.match(/\smotorErr\s/)) {devObj.motorErr = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\ssmoke_detect\s/)) {devObj.smokeDetect = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\scfgState\s/)) {devObj.cfgState = line.match(/[^\s]*$/)[0];}
				else if(line.match(/\sNAME\s/)) {deviceEnd = true;}
				
				if(deviceEnd) { //save and check info from device
					if(devObj.parentDev != devObj.name) { //current device is channelDevice
						if(informDevices.match(devObj.parentDev + ',') == null) {
							informDevices += devObj.parentDev +',';
						}
					}
					else { //current device is parentDevice
						if(devObj.commState == '') {devObj.commState = 'Info_Unknown';}
						if(devObj.actCycle != '') {
							if(devObj.actCycle == '000:00') {devObj.activity = 'switchedOff';}
							else {devObj.activity = ((devObj.actStatus != '')? devObj.actStatus: 'unknown');}
						}
						else {devObj.activity = 'unused';}
						if(devObj.IODev == '' || devObj.IODev.match(/^helper=HASH\(/)) {devObj.IODev = 'missing_IODev';}
						devObj.rssi = 'rssi_at_'+devObj.IODev+' => ' + ((devObj.rssi == '')? 'missing_rssi': devObj.rssi);
						if(devObj.aIODev == '') {devObj.aIODev = 'missing_aIODev';}
						if(devObj.IOgrp == '') {devObj.IOgrp = 'missing_IOgrp';}
					}
					if(devObj.model == '') {devObj.model = 'missing_model';}
					if(devObj.cfgState == '') {devObj.cfgState = 'Info_Unknown';}
					devMap.set(devObj.name,devObj);
				}
			}
			
			if(isFirstRun) {
				$('#'+idStr).attr('errordevices_data','first');
				informDevices = informDevices.replace(/,$/,'');
				informDevices = (informDevices == deviceList)? '': informDevices.replace(deviceList+',','');
				$('#'+idStr).attr('errordevices_list',deviceList +':'+ informDevices);
			}
			else {$('#'+idStr).attr('errordevices_data','ready');}
		}
	});
}

function HMinfoTools_changeInformChannel(informDevices) {
	if($('#hminfotools').attr('device') != null) {
		informDevices = $('#hminfotools').attr('device')+((informDevices == '')? '': ',' + informDevices);
	}
	var weblinkdiv = document.getElementById('hminfotools_weblink'); 
	if(weblinkdiv != null) { //other devices on a room-site
		//SB_PLAYER_0004201e98ec
		//SB_PLAYER_0004201e98ec-volume
		var roomDevices = '';
		$("[informid]").each(function() {
			var inform = this.getAttribute('informid');
			if(!inform.match(/-/) && !roomDevices.match(inform + ',')) {roomDevices += inform + ',';}
		});
		roomDevices = roomDevices.replace(/,$/,'');
		informDevices += ((roomDevices == '')? '': ',' + roomDevices);
	}
	document.body.setAttribute('longpollfilter',informDevices);
	FW_closeConn(); 
	setTimeout(FW_longpoll,300); // forum # 112181
}


//###### icons,longpoll #######################################################################################

function HMinfoTools_UpdateLine(d) {
	if(document.getElementById('hminfotools') == null && document.getElementById('HMdeviceTools_toolsTable') == null) {return;}
	
	if(d[0].match(/-commState$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_commState_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_commState_/,'');
			HMinfoTools_setIconFromCommState(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-Activity$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_Activity_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_Activity_/,'');
			HMinfoTools_setIconFromActivity(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-rssi_at_/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_rssi_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_rssi_/,'');
			var io = devMap.get(errDevice).IODev;
			if(d[0].match('-rssi_at_' +io+ '$')) {
				HMinfoTools_setIconFromRssi(errDevice,'rssi_at_' +io+ ' => last: ' +d[1]);
			}
		});
		return;
	}
	if(d[0].match(/-IODev$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		if(devMap.has(evtDevice) && d[1] != devMap.get(evtDevice).IODev) { //io change
			HMinfoTools_getChangedIODevData(evtDevice);
		}
		return;
	}
	if(d[0].match(/-cfgState$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_cfgState_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_cfgState_/,'');
			HMinfoTools_setIconFromCfgState(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-battery$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_battery_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_battery_/,'');
			HMinfoTools_setIconFromBattery(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-motorErr$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_motorErr_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_motorErr_/,'');
			HMinfoTools_setIconFromMotorErr(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-sabotageError$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_sabotageError_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_sabotageError_/,'');
			HMinfoTools_setIconFromSabotageError(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-sabotageAttack_ErrIoAttack_cnt$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_sabotageAttack_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_sabotageAttack_/,'');
			HMinfoTools_setIconFromSabotageAttack(errDevice,d[1]);
		});
		return;
	}
	if(d[0].match(/-smoke_detect$/)) {
		var evtDevice = d[0].match(/^[^-]+/)[0];
		$("[id^='icon_smokeDetect_'][pollid='" +evtDevice+ "']").each(function() {
			var errDevice = this.id.replace(/icon_smokeDetect_/,'');
			HMinfoTools_setIconFromSmokeDetect(errDevice,d[1]);
		});
		return;
	}

	if(document.getElementById('hminfotools') != null) {
		var hminfo = document.getElementById('hminfotools').getAttribute('device');
		//"hminfo-lastErrChange","updated:2020-07-13 16:06:02","updated:2020-07-13 16:06:02"
		if(d[0].match(hminfo + '-lastErrChange') && d[1].match(/^updated:/)) {
			HMinfoTools_updateErrorDevicesTable(hminfo,d[1]);
			return;
		}
		//"hminfo","updated:2020-08-05 11:48:28","<div id=\u0022hminfo\u0022  title=\u0022updated:2020-08-05 11:48:28\u0022 class=\u0022col2\...(173)
		if(d[0] == hminfo && document.getElementById('hminfo_ios').innerHTML == 'IO_Devices: Info_Unknown'
											&& document.getElementById('hminfo_change').innerHTML == d[1]) {
			HMinfoTools_updateErrorDevicesTable(hminfo,'');
			return;
		}
	}
}

function HMinfoTools_updateErrorDevicesTable(hminfo,lastChange) {
	devMap.clear();
	document.getElementById('hminfo_table_errDev').innerHTML = '';
	document.getElementById('hminfo_info').innerHTML = ' => updating...';
	if(lastChange != '') {document.getElementById('hminfo_change').innerHTML = lastChange;}
	var weblinkdiv = document.getElementById('hminfotools_weblink'); 
	HMinfoTools_parseErrorDevices(hminfo,weblinkdiv);
}

function HMinfoTools_createErrorDevicesTable(errorDevices) {
	var tbody = document.getElementById('hminfo_table_errDev');
	var z = 0;
	var devices = errorDevices.split(',');
	for(var d = 0; d < devices.length; ++d) {
		++z;
		var device = devices[d];
		var tr = document.createElement('tr');
		tbody.appendChild(tr);
		tr.id = 'hminfo_devRow_' + device;
		if(z%2 != 0) {tr.setAttribute('class','even');}
		else {tr.setAttribute('class','odd');}
		var td = document.createElement('td');
		tr.appendChild(td);
		HMinfoTools_createIconCells(td,device); //###############################################
		var td = document.createElement('td');
		tr.appendChild(td);
		td.innerHTML = '<a href="/fhem?detail=' +device+ '">' +device+ '</a>';
		var td = document.createElement('td');
		tr.appendChild(td);
		var errors = devMap.get(device).errors;
		td.innerHTML = errors.join(', ');
	}
	$("[id^='hminfo_devRow_']").each(function() {
		var errDevice = this.id.replace('hminfo_devRow_','');
		HMinfoTools_initIcons(errDevice); //#####################################################
	});
	document.getElementById('hminfo_info').innerHTML = '';
}

function HMinfoTools_loadIcons(device,td) {
	var hminfo = $('#hminfotools').attr('device');
	var isHMinfo = (device == $('#hminfotools').attr('device'))? true: false;
	for(var i = 0; i < HMinfoTools_icons.length; ++i) {
		var iconName = HMinfoTools_icons[i].name;
		var icon = HMinfoTools_icons[i].svg;
		var click = HMinfoTools_icons[i].clickG;
		var iconCell = document.createElement('span');
		td.appendChild(iconCell);
		iconCell.id = 'icon_' +iconName+ '_hminfo';
		if(isHMinfo && click != '') {
			iconCell.style.cursor = 'pointer';
			iconCell.title = 'on click => set ' +hminfo+ ' ' +click;
			iconCell.setAttribute('onclick',"HMinfoTools_clickSetFunctionG('"+hminfo+"','"+click+"')");
		}
		var dummy = document.createElement('span');
		td.appendChild(dummy);
		dummy.innerHTML = ' ';
		if(iconCell.innerHTML == '') {
			var cmd = "{FW_makeImage('" +icon+ "@white')}";
			if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
			var url = HMinfoTools_makeCommand(cmd);
			$.ajax({
				url: url,
				type: "GET",
				context: iconCell,
				success: function(data){
					if(data) {
						this.innerHTML = data;
						if(this.id == 'icon_commState_hminfo') {
							$('#' +this.id+ ' svg').css('height','12px');
							$('#' +this.id+ ' svg').css('width','12px');
						}
						else {
							$('#' +this.id+ ' svg').css('height','20px');
							$('#' +this.id+ ' svg').css('width','20px');
						}
						var idStr = (isHMinfo)? 'hminfotools': 'HMdeviceTools_toolsTable';
						var loadedIcons = $('#' +idStr).attr('loaded_icons');
						if(loadedIcons == 'init') {$('#' +idStr).attr('loaded_icons','1');}
						else {$('#' +idStr).attr('loaded_icons',parseInt(loadedIcons)+1);}
					}
				}
			});
		}
	}
}

function HMinfoTools_clickSetFunctionG(hminfo,click) { //set hminfo click function
	var cmd = 'set '+hminfo+' '+click;
	if(HMinfoTools_debug) {log('HMinfoTools: '+cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data) {FW_okDialog(data);}
		else {if(click == 'clearG rssi') {location.reload();}}
	});
}

function HMinfoTools_createIconCells(td,device) {
	for(var i = 0; i < HMinfoTools_icons.length; ++i) {
		var iconName = HMinfoTools_icons[i].name;
		var iconPoll = HMinfoTools_icons[i].poll;
		var iconClick = HMinfoTools_icons[i].click;
		var iconCell = document.createElement('span');
		td.appendChild(iconCell);
		iconCell.id = 'icon_' +iconName+ '_' + device;
		if(iconClick != '' && iconName != 'cfgState' && iconName != 'battery' && iconName != 'sabotageAttack') { //only if icons exist on any devices
			iconCell.style.cursor = 'pointer';
			iconCell.setAttribute('onclick',iconClick +"('"+ device + "')");
		}
		iconCell.setAttribute('pollid',((iconPoll == 'parent')? devMap.get(device).parentDev: device));
		iconCell.innerHTML = document.getElementById('icon_' +iconName+ '_hminfo').innerHTML;
		var idStr = iconCell.id.replace(/\./g,'\\.');
		if(iconName == 'Activity' && devMap.get(device).model.match(/^(missing_model|CCU-FHEM|VIRTUAL)$/)) { //virtual device
			$('#' +idStr+ ' path').css('visibility','hidden');
		}
		else if(iconName == 'battery') {
			$('#' +idStr+ ' path').css('visibility','hidden');
		}
		else if(iconName == 'motorErr') {
			$('#' +idStr+ ' path').css('visibility','hidden');
		}
		else if(iconName == 'smokeDetect') {
			$('#' +idStr+ ' path').css('visibility','hidden');
		}
		else if(iconName == 'sabotageAttack') {
			$('#' +idStr+ ' path').css('visibility','hidden');
			$('#' +idStr+ ' rect').css('visibility','hidden');
			$('#' +idStr+ ' polygon').css('visibility','hidden');
		}
		else if(iconName == 'sabotageError') {
			$('#' +idStr+ ' g').css('visibility','hidden');
		}
		var dummy = document.createElement('span');
		td.appendChild(dummy);
		dummy.innerHTML = ' ';
	}
}

function HMinfoTools_initIcons(device) {
	var devObj = devMap.get(device);
	if(device != devObj.parentDev) { //device is channelDevice
		var parObj = devMap.get(devObj.parentDev);
		devObj.commState = parObj.commState;
		devObj.activity = parObj.activity;
		devObj.rssi = parObj.rssi;
		devObj.IODev = parObj.IODev;
		devObj.aIODev = parObj.aIODev;
		devObj.IOgrp = parObj.IOgrp;
		devObj.battery = parObj.battery;
		devObj.sabotageError = parObj.sabotageError;
		devObj.sabotageAttack = parObj.sabotageAttack;
		devMap.set(devObj.name,devObj);
	}
	//all entities use these icons
	HMinfoTools_setIconFromCommState(device,devObj.commState);
	HMinfoTools_setIconFromRssi(device,devObj.rssi);
	HMinfoTools_setIconFromIODev(device,devObj.IODev);
	HMinfoTools_setIconFromCfgState(device,devObj.cfgState);
	// only some entities use these icons
	if(!devObj.model.match(/^(missing_model|CCU-FHEM|VIRTUAL)$/)) {HMinfoTools_setIconFromActivity(device,devObj.activity);}
	if(devObj.battery != '') {HMinfoTools_setIconFromBattery(device,devObj.battery);}
	if(devObj.motorErr != '') {HMinfoTools_setIconFromMotorErr(device,devObj.motorErr);}
	if(devObj.sabotageError != '') {HMinfoTools_setIconFromSabotageError(device,devObj.sabotageError);}
	if(devObj.sabotageAttack != '') {HMinfoTools_setIconFromSabotageAttack(device,devObj.sabotageAttack);}
	if(devObj.smokeDetect != '') {HMinfoTools_setIconFromSmokeDetect(device,devObj.smokeDetect);}
}

//###### icon functions for devices ##############################################################################

function HMinfoTools_setIconFromCommState(device,commState) {
	/*
	color       commState
	---------------------------------------------------------
	white       Info_Cleared, Info_Unknown (missing reading)
	yellow      CMDs_processing..., CMDs_FWupdate
	orange      CMDs_pending
	red         CMDs_done_Errors:1
	green       CMDs_done, CMDs_done_FWupdate
	*/
	var color = 'white';
	if(commState.match(/^(Info_Cleared|Info_Unknown)$/)) {color = 'white';}
	else if(commState.match(/^(CMDs_done|CMDs_done_FWupdate)$/)) {color = 'lime';}
	else if(commState.match(/^(CMDs_processing...|CMDs_FWupdate)$/)) {color = 'yellow';}
	else if(commState.match(/^CMDs_pending$/)) {color = 'orange';}
	else if(commState.match(/^CMDs_done_Errors:/)) {color = 'red';}
	
	var iconCommState = document.getElementById('icon_commState_' + device);
	iconCommState.title = 'commState: ' +commState+ '\non click => set ' +devMap.get(device).parentDev+ ' clear msgEvents';

	var led = iconCommState.querySelector('path');
	var blinkLed = led.animate([{fill: color},{fill: 'black'}], {
										duration: 1000, 
										iterations: Infinity, 
										easing: 'ease-in' 
									});
	if(color == 'orange') {
		blinkLed.play();
	}
	else {
		blinkLed.pause();
		led.setAttribute('fill','black');
		setTimeout(led.setAttribute('fill',color),300);
	}
}

function HMinfoTools_setClearMsgEvents(device) { //click commstate
	var parentDev = devMap.get(device).parentDev;
	var cmd = 'set '+parentDev+' clear msgEvents';
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data) {FW_okDialog(data);}
	});
}

function HMinfoTools_setIconFromRssi(device,rssiList) {
	/*
	hminfo: I_rssiMinLevel	59<:11 60>:10 80>:4 99>:1
	color    rssi                  special
	-----------------------------------------------------
	white    missing_rssi
	green    -80 <  rssi
	yellow   -90 <  rssi <= -80
	orange   -99 <= rssi <= -90
	red             rssi <  -99    ,missing_IODev
	*/
	var color = 'white';
	if(rssiList.match(/^missing_IODev$/)) {color = 'red';}
	else {
		var rssi;
		if(!rssiList.match(/last:/)) {
			//rssi_at_cul868 => cnt:484 min:-39.5 max:-38 avg:-39.09 lst:-39.5
			var mRssi = rssiList.match(/min:([^\s]*)/);
			rssi = (mRssi != null && mRssi[1] != undefined)? mRssi[1]: '';
		}
		else {
			//rssi_at_cul868 => last: -39.5
			var mRssi = rssiList.match(/last:\s(.*)$/);
			rssi = (mRssi != null && mRssi[1] != undefined)? mRssi[1]: '';
		}
		if(rssi != '') {
			if(-80 < rssi) {color = 'lime';}
			else if(-90 < rssi && rssi <= -80) {color = 'yellow';}
			else if(-99 <= rssi && rssi <= -90) {color = 'orange';}
			else if(rssi < -99) {color = 'red';}
		}
		else {color = 'white';}
	}
	
	var iconRssi = document.getElementById('icon_rssi_' + device);
	iconRssi.title = rssiList + '\non click => set ' +devMap.get(device).parentDev+ ' clear rssi';

	var devStr = device.replace(/\./g,'\\.');
	var bColor = $('#icon_rssi_' + devStr).css('background-color');
	$('#icon_rssi_'+devStr+' g').css('fill',bColor);
	setTimeout(function(){
		$('#icon_rssi_'+devStr+' g').css('fill',color);
		if(rssiList.match(/last:/)) {$('#icon_rssi_'+devStr+" path[d^='M1319']").css('fill','white');}
	},300);
}

function HMinfoTools_setClearRssi(device) { //click rssi
	var parentDev = devMap.get(device).parentDev;
	var cmd = 'set '+parentDev+' clear rssi';
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data) {FW_okDialog(data);}
		else {
			var cmd = 'jsonlist2 ' + parentDev;
			if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
			var url = HMinfoTools_makeCommand(cmd);
			$.get(url,function(data) {
				if(data) {
					var object = data.Results[0];
					var internalsString = JSON.stringify(object.Internals);
					var curIoDev = (object.Internals.IODev != null)? 
													object.Internals.IODev: 'missing_IODev';
					var curIoRssi = 'rssi_at_'+curIoDev+' => ' + ((internalsString.match('rssi_at_'+curIoDev))? 
																										 object.Internals['rssi_at_'+curIoDev]: 
																										 'missing_rssi');
					HMinfoTools_setIconFromRssi(device,curIoRssi);
				}
			});
		}
	});
}

function HMinfoTools_getChangedIODevData(device) {
	var cmd = 'jsonlist2 ' + device;
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		var object = data.Results[0];
		if(object) {
			var devObj = devMap.get(device);
			devObj.IODev = (object.Internals.IODev != null)
												? object.Internals.IODev
												: 'missing_IODev';
			devObj.aIODev = (object.Attributes.IODev != null)
												? object.Attributes.IODev
												: 'missing_aIODev';
			devObj.IOgrp = (object.Attributes.IOgrp != null)
												? object.Attributes.IOgrp
												: 'missing_IOgrp';
			var internalsString = JSON.stringify(object.Internals);
			devObj.rssi = 'rssi_at_'+devObj.IODev+' => ' + ((internalsString.match('rssi_at_'+devObj.IODev))
																												? object.Internals['rssi_at_'+devObj.IODev]
																												: 'missing_rssi');
			devMap.set(device,devObj);

			$("[id^='icon_IODev_'][pollid='" +device+ "']").each(function() {
				var errDevice = this.id.replace(/icon_IODev_/,'');
				if(errDevice != device) {
					var errDevObj = devMap.get(errDevice);
					errDevObj.IODev = devObj.IODev;
					errDevObj.aIODev = devObj.aIODev;
					errDevObj.IOgrp = devObj.IOgrp;
					errDevObj.rssi = devObj.rssi;
					devMap.set(errDevice,errDevObj);
				}
				HMinfoTools_setIconFromIODev(errDevice,devObj.IODev);
				HMinfoTools_setIconFromRssi(errDevice,devObj.rssi);
			});
		}
	});
}

function HMinfoTools_setIconFromIODev(device,iodev) {
	// color			attr IOgrp set                              attr IODev set                           none
	// --------------------------------------------------------------------------------------------------------
	// white			no prefered set                                                         
	// green	    1. prefered                                 reading = attr
	// yellow			2. prefered
	// orange			no prefered
	// red				no prefered (opt none), missing_IODev       reading != attr, missing_IODev           only red
	var devObj = devMap.get(device);
	var IOgrp = devObj.IOgrp;
	var aIODev = devObj.aIODev;
	var color = 'blue'; // missing category
	var text = ' (missing category!!!)';
	
	if(iodev == 'missing_IODev') {color = 'red';}                    // no io in use
	else if(IOgrp && IOgrp != 'missing_IOgrp') {                     // we use vccu
		text = ' (desired => ' +IOgrp+ ')';
		if(IOgrp.match(/:.+$/)) {                                      // we use prefered 
			if(IOgrp.match(':'+iodev)) {color = 'lime';}
			else if(IOgrp.match(','+iodev)) {color = 'yellow';}
			else if(!IOgrp.match(iodev) && !IOgrp.match(/none/)) {color = 'orange';}
			else if(!IOgrp.match(iodev) && IOgrp.match(/none/)) {color = 'red';}
		}
		else {                                                         // we use no prefered
			var vccu = IOgrp.match(/^[^:]+/);
			var vcculist = $('#hminfotools').attr('vcculist');
			isIOmember = (vcculist.match('(?:^|\\s)' +vccu+ ':[^\\s]*?' +iodev+ '[,\\s]'))? true: false;
			if(vcculist == '') {isIOmember = true;} // for old versions without vcculist
			if(isIOmember) {color = 'white';}
			else {color = 'red';}
		}
	}
	else if(IOgrp == 'missing_IOgrp' && aIODev == 'missing_aIODev') { // no attributes
		color = 'red';
		text = ' (nothing is desired!!!)';
	}
	else {                                                            // only attr IODev
		text = ' (desired => ' +aIODev+ ')';
		if(iodev == aIODev) {color = 'lime';}
		else {color = 'red';}
	}
	
	var iconIODev = document.getElementById('icon_IODev_' + device);
	iconIODev.title = 'IODev: ' +iodev+ text;

	var devStr = device.replace(/\./g,'\\.');
	var bColor = $('#icon_IODev_' + devStr).css('background-color');
	$('#icon_IODev_' +devStr+ ' path').css('fill',bColor);
	//$('#icon_IODev_' +devStr+ ' path').animate({fill: color},1500);


	setTimeout(function(){
		$('#icon_IODev_' +devStr+ ' path').css('fill',color);
	},50);

//#############################################################
/*	
	var led = iconIODev.querySelector('g');
	var blinkLed = led.animate([{fill: 'black'},{fill: color}], {
										duration: 500, 
										iterations: 5, 
										easing: 'ease-out' 
									});
	blinkLed.play();
	*/
	/*
	if(color == 'orange') {
		blinkLed.play();
	}
	else {
		blinkLed.pause();
		led.setAttribute('fill','black');
		setTimeout(led.setAttribute('fill',color),300);
	}
	*/

}

function HMinfoTools_setIconFromCfgState(device,cfgState) {
	/*
	color       cfgState
	--------------------------------------------------------
	green       "ok"
	white       "Info_Unknown" (no reading)
	orange      "updating"
	red         error list
	*/
	var color = 'white';
	if(cfgState == 'ok') {color = 'lime';}
	else if(cfgState == 'Info_Unknown') {color = 'white';}
	else if(cfgState == 'updating') {color = 'orange';}
	else {color = 'red';}

	var iconCfgState = document.getElementById('icon_cfgState_' + device);
	var clickFunction;
	if(devMap.get(device).model.match(/^(missing_model|CCU-FHEM|VIRTUAL)$/)) {clickFunction = '';}
	else {
		clickFunction = '\non click => set ' +device+ ' getConfig';
		iconCfgState.style.cursor = 'pointer';
		iconCfgState.setAttribute('onclick',"HMinfoTools_setGetConfig('"+device+"')");
	}

	if(color == 'red') {
	/*
	 Device name:SwitchPBU06
		 mId      	:0069  Model=HM-LC-SW1PBU-FM
		 mode   	:normal - activity:alive
		 protState	: CMDs_done_Errors:1 pending: none

	 configuration check: updating
		 RegMiss: missing register list
				=>RegL_00.,RegL_01.,RegL_03.Tuer.SZ_chn-01,RegL_03.self01,RegL_03.self02
		 TmplChk: template mismatch
				=>self01:short->autoOff - OnTime :set_20 should 20 
	*/
		var cmd = 'get ' +device+ ' deviceInfo short';
		if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
		var url = HMinfoTools_makeCommand(cmd);
		$.get(url, function(data){
			if(data) {
				iconCfgState.title = data + clickFunction;
				if(cfgState.match(/TmplChk/) && document.getElementById('HMdeviceTools_toolsTable') != null) {
					var lines = data.split('\n');
					for(var l = 0; l < lines.length; ++l) {
						var line = lines[l];
						if(line.match(/=>.+?:.+?->.+?(?:reg\snot\sfound|should)/)) {
							//=>self01:short->autoOff - OnTime :set_20 should 20 
							var mIdx = line.trim().match(/=>([^:]+)/);
							var peer = (mIdx[1] == 0)? 'dev': mIdx[1];
							var link = document.getElementById('HMdeviceTools_reg_link_' + peer);
							if(link.style.color != 'red') {link.style.color = 'red';};
						}
					}
					$("[id^='HMdeviceTools_reg_link_']").each(function() {
						if(this.style.color.match(/^(yellow)$/)) {this.style.color = 'lime';}
					});
				}
			}
		});
	}
	else {iconCfgState.title = 'cfgState: ' +cfgState+ clickFunction;}
	var iconFill = iconCfgState.querySelector('g');
	iconFill.setAttribute('fill',color);
	
	if(!cfgState.match(/TmplChk/) && document.getElementById('HMdeviceTools_toolsTable') != null) {
		$("[id^='HMdeviceTools_reg_link_']").each(function() {
			if(cfgState == 'Info_Unknown' || cfgState == 'updating') {
				if(this.style.color.match(/^(lime|red)$/)) {this.style.color = 'yellow';}
			}
			else {
				if(this.style.color.match(/^(yellow|red)$/)) {this.style.color = 'lime';}
			}
		});
	}
	
}

function HMinfoTools_setGetConfig(device) { //click cfgState
	var cmd = 'set '+device+' getConfig';
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data) {FW_okDialog(data);}
	});
}

function HMinfoTools_setIconFromActivity(device,activity) {
	// color			activity
	// ------------------------------------------
	// white			unused (no attr actCycle)
	// yellow			switchedOff (actCycle = 000:00)
	// orange			unknown
	// red				dead
	// green	    alive
	var color = 'white';
	if(activity == 'unused') {color = 'white';}
	else if(activity == 'switchedOff') {color = 'yellow';}
	else if(activity == 'unknown') {color = 'orange';}
	else if(activity == 'dead') {color = 'red';}
	else if(activity == 'alive') {color = 'lime';}
	
	var devStr = device.replace(/\./g,'\\.');
	$('#icon_Activity_' +devStr).attr('title','Activity: '+activity);
	$('#icon_Activity_' +devStr+ ' path').css('fill',color);
}

function HMinfoTools_setIconFromBattery(device,battery) {
	// color     battery
	// --------------------------
	// green     ok
	// orange    low
	// red       critical
	var devStr = device.replace(/\./g,'\\.');
	var color = 'white';
	if(battery == 'ok') {
		color = 'lime';
		$('#icon_battery_'+devStr+" path[id='path23']").show();
		$('#icon_battery_'+devStr+" path[id='path27']").show();
	}
	else if(battery == 'low') {
		color = 'orange';
		$('#icon_battery_'+devStr+" path[id='path23']").hide();
		$('#icon_battery_'+devStr+" path[id='path27']").show();
	}
	else if(battery == 'critical') {
		color = 'red';
		$('#icon_battery_'+devStr+" path[id='path23']").hide();
		$('#icon_battery_'+devStr+" path[id='path27']").hide();
	}
	
	$('#icon_battery_' +devStr).css('cursor','pointer');
	$('#icon_battery_' +devStr).attr('onclick',"HMinfoTools_setBatteryChange('"+devStr+"')");
	$('#icon_battery_' +devStr).attr('title','battery: '+battery+ '\non click => edit: attr ' +devMap.get(device).parentDev+ ' comment');

	var bColor = $('#icon_battery_' + devStr).css('background-color');
	$('#icon_battery_' +devStr+ ' path').css('fill',bColor);
	$('#icon_battery_' +devStr+ ' path').css('visibility','visible');
	setTimeout(function(){
		$('#icon_battery_'+devStr+' path').css('fill',color);
	},300);
}

function HMinfoTools_setBatteryChange(device) { //click battery
	$('#icon_battery_' +device.replace(/\./g,'\\.')+ ' path').css('fill','white');
	var devObj = devMap.get(device);
	var cmd = 'jsonlist2 '+devObj.parentDev;
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		var object = data.Results[0];
		if(object != null) {
			var oldComment = object.Attributes.comment;
			var oldTxt = (oldComment == null)? '': object.Attributes.comment + '\n';
			var d = new Date();
			var ts = d.getFullYear()+'-'+('0'+(d.getMonth()+1)).slice(-2)+'-'+('0'+d.getDate()).slice(-2)+' '+
							('0'+d.getHours()).slice(-2)+':'+('0'+d.getMinutes()).slice(-2)+':'+('0'+d.getSeconds()).slice(-2);
			devObj.battery = object.Readings.battery.Value;
			devMap.set(device,devObj);
			var batNotOkFirstTime = (object.Readings.batNotOkFirstTime != null && 
				object.Readings.batNotOkFirstTime.Value.match(/^[0-9]{4}-[0-9]{2}-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}$/))? 
				object.Readings.batNotOkFirstTime.Value: object.Readings.battery.Time;
			var oldStat = '(oldBat: '+devObj.battery+' since '+batNotOkFirstTime+')';
			var newTxt = 'batChange: '+ts+' '+oldStat;
			var div = $("<div id='FW_okDialog'>");
			$(div).html('Do you realy want a new battery-change-entry for "attr '+device+' comment"?'+
									"<br><br><textarea id='hminfotools_batchange'>"+oldTxt+newTxt+'</textarea>');
			$("body").append(div);
			var area = document.getElementById('hminfotools_batchange');
			area.rows = 5;
			//area.style.minWidth = "calc(100% - 30px)";
			area.focus();
			area.selectionStart = area.value.length - newTxt.length;
			if(area.selectionStart > 0) {--area.selectionStart;}
			area.selectionEnd = area.value.length;

			function doClose() {
				$(div).dialog("close"); $(div).remove();
				HMinfoTools_setIconFromBattery(device,devObj.battery);
			}
			function doEntry() {
				var comment = $('#hminfotools_batchange').val();
				var cmd;
				if(oldComment == null && comment == '') {return;}
				else if(oldComment != null && comment == '') {cmd = 'deleteattr ' +devObj.parentDev+ ' comment';}
				else {
					cmd = 'attr ' +devObj.parentDev+ ' comment ' + comment;
					if(object.Readings.batNotOkCtr != null) {cmd += ';setreading ' +devObj.parentDev+ ' batNotOkCtr 0';}
				}
				if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
				var url = HMinfoTools_makeCommand(cmd);
				$.get(url,function(data) {if(data) {FW_okDialog(data);}});
			}
			$(div).dialog({
				dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
				maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
				buttons: [{text:"Yes", click:function(){ doEntry(); doClose();}},
									{text:"No",  click:function(){ doClose();}}]
			});
		}
		else {
			HMinfoTools_setIconFromBattery(device,devObj.battery);
		}
	});
}

function HMinfoTools_setIconFromMotorErr(device,motorErr) {
	// color     motorErr
	// --------------------------
	// green     ok
	// red       error
	var color = 'white';
	if(motorErr == 'ok') {color = 'lime';}
	else {color = 'red';}
	
	$('#icon_motorErr_' +device.replace(/\./g,'\\.')).attr('title','motorErr: '+motorErr);
	$('#icon_motorErr_' +device.replace(/\./g,'\\.')+ ' path').css('fill',color);
	$('#icon_motorErr_' +device.replace(/\./g,'\\.')+ ' path').css('visibility','visible');
}

function HMinfoTools_setIconFromSabotageError(device,sabotageError) {
	// color			sabotageError
	// -------------------
	// green		  off
	// red				on
	var color = 'white';
	if(sabotageError == 'off') {color = 'lime';}
	else if(sabotageError == 'on') {color = 'red';}
	
	$('#icon_sabotageError_'+device.replace(/\./g,'\\.')).attr('title','sabotageError: ' + sabotageError);
	$('#icon_sabotageError_'+device.replace(/\./g,'\\.')+' g').css('fill',color);
	$('#icon_sabotageError_'+device.replace(/\./g,'\\.')+' g').css('visibility','visible');
}

function HMinfoTools_setIconFromSabotageAttack(device,attack) {
	// color			attack
	// -------------------
	// red				attack
	var color = 'red';
	
	var devStr = device.replace(/\./g,'\\.');
	$('#icon_sabotageAttack_'+devStr).attr('title','sabotageAttack_ErrIoAttack_cnt: ' + attack
																					+ '\non click => set ' +devMap.get(device).parentDev+ ' clear attack');
	$('#icon_sabotageAttack_'+devStr).css('cursor','pointer');
	$('#icon_sabotageAttack_'+devStr).attr('onclick',"HMinfoTools_setClearAttack('"+devStr+"')");
	$('#icon_sabotageAttack_'+devStr+' path').css('fill',color);
	$('#icon_sabotageAttack_'+devStr+' rect').css('fill',color);
	$('#icon_sabotageAttack_'+devStr+' polygon').css('fill',color);
	$('#icon_sabotageAttack_'+devStr+' path').css('visibility','visible');
	$('#icon_sabotageAttack_'+devStr+' rect').css('visibility','visible');
	$('#icon_sabotageAttack_'+devStr+' polygon').css('visibility','visible');

	var iconAttack = document.getElementById('icon_sabotageAttack_' + device);
	var led1 = iconAttack.querySelector('path');
	var led2 = iconAttack.querySelector('rect');
	var led3 = iconAttack.querySelector('polygon');
	led1.animate([{fill: color},{fill: 'black'}], {
		duration: 1000, 
		iterations: 5, 
		easing: 'ease-in' 
	});
	led2.animate([{fill: color},{fill: 'black'}], {
		duration: 1000, 
		iterations: 5, 
		easing: 'ease-in' 
	});
	led3.animate([{fill: color},{fill: 'black'}], {
		duration: 1000, 
		iterations: 5, 
		easing: 'ease-in' 
	});
}

function HMinfoTools_setClearAttack(device) { //click sabotageAttack
	var parentDev = devMap.get(device).parentDev;
	var cmd = 'set '+parentDev+' clear attack';
	if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
	var url = HMinfoTools_makeCommand(cmd);
	$.get(url,function(data) {
		if(data) {FW_okDialog(data);}
		else {
			var cmd = 'jsonlist2 ' + parentDev;
			if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
			var url = HMinfoTools_makeCommand(cmd);
			$.get(url,function(data) {
				var object = data.Results[0];
				if(object) {
					if(object.Readings.sabotageAttack_ErrIoAttack_cnt != null) {
						HMinfoTools_setIconFromSabotageAttack(object.Readings.sabotageAttack_ErrIoAttack_cnt.Value);
					}
					else {
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')).removeAttr('title');
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')).css('cursor','');
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')).removeAttr('onclick');
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')+' path').css('visibility','hidden');
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')+' rect').css('visibility','hidden');
						$('#icon_sabotageAttack_'+device.replace(/\./g,'\\.')+' polygon').css('visibility','hidden');
					}
				}
			});
		}
	});
}

function HMinfoTools_setIconFromSmokeDetect(device,smokeDetect) {
	// color     smoke_detect
	// --------------------------
	// green     none
	// red       error
	var color = 'white';
	if(smokeDetect == 'none') {color = 'lime';}
	else {color = 'red';}
	
	$('#icon_smokeDetect_' +device.replace(/\./g,'\\.')).attr('title','smoke_detect: '+smokeDetect);
	$('#icon_smokeDetect_' +device.replace(/\./g,'\\.')+ ' path').css('fill',color);
	$('#icon_smokeDetect_' +device.replace(/\./g,'\\.')+ ' path').css('visibility','visible');
}

//##### end => icon functions ######################################################

function HMinfoTools_createScreenshot() {
	/* https://github.com/niklasvh/html2canvas/issues/2457
	html2canvas(target).then(() => {
		html2canvas(target).then(res => {
			//your code here 
		})
	})
	var range = document.createRange();
	range.selectNode(textNode);
	var rect = range.getBoundingClientRect();
	*/
	
	//var tab = document.body;
	//var tab = document.getElementById("hminfotools");
	var tab = document.getElementById("devicetable");
	var tabRect = tab.getBoundingClientRect(); //
	//Object.freeze(tab);
	var user = navigator.userAgent;
	
	//html2canvas(tab).then(() => { //new experiment => not better
		html2canvas(tab, {
			logging: false, 
			width: tabRect.width,
			height: tabRect.height,
			x: 190,
			y: 205
		}).then(canvas => {
			var dataURL = canvas.toDataURL('image/png');
			//var cmd = "{HMinfoTools_saveScreenshot("+encodeURIComponent(user)+")}";
			var cmd = "{HMinfoTools_saveScreenshot('test')}";
			if(HMinfoTools_debug) {log('HMinfoTools: ' + cmd);}
			var url = HMinfoTools_makeCommand(cmd);
			$.ajax({url: url,type: "POST",
				data: {fileContent: dataURL},
				contentType: 'image/png',
				success: function(data){if(data) {}}
			});
		//}); //new experiment => not better
	});
}

function HMinfoTools_getBaseUrl() {
  var url = window.location.href.split('?')[0];
  url += '?';
  if(HMinfoTools_csrf != null) {url += 'fwcsrf=' +HMinfoTools_csrf+ '&';}
  return url;
}

function HMinfoTools_makeCommand(cmd) {
  return HMinfoTools_getBaseUrl() + 'cmd=' +encodeURIComponent(cmd)+ '&XHR=1';
}

FW_widgets['homematicInfoTools'] = {
  //createFn:HMinfoTools_Create,
  updateLine:HMinfoTools_UpdateLine
};
