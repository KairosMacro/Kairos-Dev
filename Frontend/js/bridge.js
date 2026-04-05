const featureCheckboxes = [
	"WarnsEnabled", "BoostBarEnabled", "TrackerEnabled",
	"MagnifierEnabled", "AltMacroEnabled", "StatMonitorEnabled",
	"KeyAlignmentEnabled"
];
let selectedBoostSlot = 1;
let boostSlotModes = { 1: "", 2: "", 3: "", 4: "", 5: "", 6: "", 7: "" };
const availableModes = ["Timer", "ReGlitter", "On Scorch", "ReSmoothie", "On Pop Star", "On Baller", "On Shower", "On Gummy"];

window.chrome.webview.addEventListener('message', function(Msg) {
	const configData = Msg.data;
	if (configData.PresetList) {
		const ddl = document.getElementById("PresetDDL");
		if (ddl) {
			ddl.innerHTML = "";
			configData.PresetList.forEach(preset => {
				let opt = document.createElement("option");
				opt.value = preset;
				opt.innerText = preset;
				ddl.appendChild(opt);
			});
		}
	}
	if (configData.PatternList) {
		const ddl = document.getElementById("Pattern");
		if (ddl) {
			ddl.innerHTML = "";
			configData.PatternList.forEach(pat => {
				let opt = document.createElement("option");
				opt.value = pat;
				opt.innerText = pat;
				ddl.appendChild(opt);
			});
		}
	}
	for (const [key, value] of Object.entries(configData)) {
		if (key === "PresetList" || key === "PatternList") continue;
		if (key.startsWith("SlotMode")) {
			const slotNum = parseInt(key.replace("SlotMode", ""));
			if (!isNaN(slotNum)) {
				boostSlotModes[slotNum] = value;
			}
			continue;
		}
		if (key === "Passives") {
			const passivesArr = value.split('|');
			const passiveIds = {
				"precise": "Precision",
				"supersmoothie": "SuperSmoothie",
				"combo": "CoconutCombo",
				"scorch": "Scorch",
				"x-flame": "XFlame",
				"gummystar": "GummyStar",
				"gummymorph": "GummyMorph",
				"gummyballer": "GummyBaller",
				"popstar": "PopStar"
			};
			for (let p in passiveIds) {
				let ele = document.getElementById(passiveIds[p]);
				if (ele) ele.checked = passivesArr.includes(p);
			}
			continue;
		}
		let ele = document.getElementById(key);
		if (ele) {
			if (ele.type === "checkbox") {
				ele.checked = (value === 1 || value === "1" || value === true || value === "true");
			} else if (ele.tagName === "SPAN" || ele.tagName === "DIV") {
				ele.innerText = value;
			} else {
				ele.value = value;
			}
			if (key.includes('_Volume')) {
				let volLabel = document.getElementById('lbl_' + key);
				if (volLabel) volLabel.innerText = value;
			}
		}
	}
	updateAccountUI();
	updateCurrentlyToggled();
	refreshModeCheckboxes();
	updateCommsIndicator();
});

function attachConfigListeners() {
	const inputs = document.querySelectorAll('.config-sync');
	inputs.forEach(input => {
		if (!input.dataset.listenerAttached) {
			input.addEventListener('input', (e) => {
				const ele = e.target;
				const section = ele.getAttribute('data-section');
				const key = ele.id; 
				let value;
				if (ele.type === 'checkbox') {
					value = ele.checked ? 1 : 0; 
				} else if (ele.type === 'number') {
					value = ele.value === '' ? 0 : parseFloat(ele.value);
				} else {
					value = ele.value;
				}
				
				window.chrome.webview.hostObjects.ahkChangeSetting.func(value, section, key);
				if (key === 'AccountType') {
					updateAccountUI();
				}
				if (featureCheckboxes.includes(key)) {
					updateCurrentlyToggled();
				}
				if (key === 'CommunicationEnabled') {
					updateCommsIndicator();
				}
			});
			input.dataset.listenerAttached = 'true';
		}
	});
}

function updateCurrentlyToggled() {
	let active = [];
	featureCheckboxes.forEach(id => {
		const el = document.getElementById(id);
		const wrap = document.getElementById('wrap_' + id);
		
		let isHidden = wrap ? wrap.classList.contains('hidden') : false;
		if (el && el.checked && !isHidden) {
			active.push(id.replace("Enabled", "").replace("Macro", ""));
		}
	});
	
	const label = document.getElementById('lbl_ActiveFeatures');
	const container = document.getElementById('toggled_container');
	if (label) {
		const text = active.length > 0 ? active.join(', ') : 'None';
		label.innerText = text;
		label.className = active.length > 0 ? 'text-[#974EC2] font-medium' : 'text-gray-500 font-medium';
		if (container) {
			container.title = active.length > 0 ? "Currently Toggled: " + text : "";
		}
	}
}

function updateAccountUI() {
	const type = document.getElementById("AccountType")?.value || "Main";
	
	document.getElementById('wrap_AltMacroEnabled')?.classList.toggle('hidden', type === 'Main');
	document.getElementById('wrap_TrackerEnabled')?.classList.toggle('hidden', type === 'Alt');
	document.getElementById('wrap_WarnsEnabled')?.classList.toggle('hidden', type === 'Alt');
	document.getElementById('wrap_StatMonitorEnabled')?.classList.toggle('hidden', type === 'Alt');
	document.getElementById('wrap_KeyAlignmentEnabled')?.classList.toggle('hidden', type === 'Alt');
	document.getElementById('wrap_MagnifierEnabled')?.classList.toggle('hidden', type === 'Alt');

	document.getElementById('Alt')?.classList.toggle('hidden', type === 'Main');
	document.getElementById('Warnings')?.classList.toggle('hidden', type === 'Alt');
	document.getElementById('Tracker')?.classList.toggle('hidden', type === 'Alt');
	let activeTab = document.getElementsByClassName("active")[0];
	if (activeTab) {
		if (type === 'Alt' && (activeTab.id === 'Warnings' || activeTab.id === 'Tracker')) {
			changeTab(document.getElementById('Home'));
		}
		if (type === 'Main' && activeTab.id === 'Alt') {
			changeTab(document.getElementById('Home'));
		}
	}
	const roleLabel = document.getElementById('lbl_CommsRole');
	if (roleLabel) {
		roleLabel.innerText = type === 'Main' ? 'Role: Server' : 'Role: Client';
	}
	updateCurrentlyToggled();
}

document.addEventListener('DOMContentLoaded', function () {
	const warnItems = [
		{ key: "Precise", name: "Precision", unit: "s", max: 60 },
		{ key: "Smoothie", name: "Super Smoothie", unit: "s", max: 1200 },
		{ key: "Gummy", name: "Gummy Star", unit: "x", max: 75 },
		{ key: "Pop", name: "Pop Star", unit: "x", max: 30 },
		{ key: "Scorch", name: "Scorching Star", unit: "x", max: 30 },
		{ key: "Shower", name: "Star Shower", unit: "x", max: 25 },
		{ key: "Morph", name: "Gummy Morph", unit: "x", max: 30 },
		{ key: "Baller", name: "Gummyballer", unit: "x", max: 1000 },
		{ key: "Combo", name: "Coconut Combo", unit: "x", max: 40 }
	];
	const warnContainer = document.getElementById('WarningsContainer');
	if (warnContainer) {
		let html = '';
		warnItems.forEach(item => {
			html += `
				<div class="flex flex-col bg-white/5 rounded-lg border border-white/5 shadow-sm overflow-hidden mb-1 transition-all">
					
					<div class="grid grid-cols-12 gap-2 items-center py-1 px-2.5">
						<div class="col-span-5 flex items-center gap-2">
							<input type="checkbox" id="${item.key}_Enabled" data-section="Warns" class="config-sync">
							<span class="text-xs font-medium text-gray-200">${item.name}</span>
						</div>
						<div class="col-span-4 flex items-center justify-center gap-1.5">
							<input type="number" id="${item.key}_Threshold" data-section="Warns" min="0" max="${item.max}" class="config-sync bg-black/60 border border-white/10 rounded px-1.5 py-0.5 w-12 text-center text-[11px] outline-none focus:border-[#504099] transition">
							<span class="text-[9px] text-gray-500">/ ${item.max}${item.unit}</span>
						</div>
						<div class="col-span-3 flex justify-center">
							<button onclick="document.getElementById('settings_${item.key}').classList.toggle('hidden')" class="bg-[#313865] hover:bg-[#504099] text-white text-[9px] uppercase tracking-wider px-2 py-0.5 rounded transition shadow-sm w-full">
								Settings ⏷
							</button>
						</div>
					</div>

					<div id="settings_${item.key}" class="hidden flex-col gap-2 p-2 bg-black/30 border-t border-white/5">
						
						<div class="flex items-center justify-between gap-3">
							<div class="flex items-center gap-2 flex-1">
								<span class="text-[10px] text-gray-400 font-bold uppercase tracking-wider">Vol:</span>
								<input type="range" id="${item.key}_Volume" data-section="Warns" min="0" max="100" class="config-sync flex-1 accent-[#504099]" oninput="document.getElementById('lbl_${item.key}_Volume').innerText = this.value">
								<span id="lbl_${item.key}_Volume" class="text-[10px] text-gray-300 w-6 text-right">25</span><span class="text-[10px] text-gray-500">%</span>
							</div>
							
							<label class="flex items-center gap-1.5">
								<input type="checkbox" id="${item.key}_PlayOnce" data-section="Warns" class="config-sync">
								<span class="text-[10px] text-gray-400 font-bold uppercase tracking-wider">Play Once</span>
							</label>
						</div>

						<div class="flex items-center gap-1.5">
							<input type="text" id="${item.key}_SoundFile" data-section="Warns" readonly class="config-sync bg-black/60 border border-white/10 rounded px-1.5 py-1 flex-1 text-[9px] text-gray-500 outline-none truncate" title="Audio File Path">
							
							<button onclick="ahkAction('BrowseSound|${item.key}')" class="bg-white/10 hover:bg-white/20 text-gray-300 text-[9px] uppercase tracking-wider px-2 py-1 rounded transition">Browse</button>
							<button onclick="ahkAction('TestSound|${item.key}')" class="bg-[#313865] hover:bg-[#504099] text-white text-[9px] uppercase tracking-wider px-2 py-1 rounded transition">Test</button>
						</div>

					</div>
				</div>
			`;
		});
		warnContainer.innerHTML = html;
	}

	const boostContainer = document.getElementById('BoostBarSlotsContainer');
	if (boostContainer) {
		let boostHtml = '';
		for (let i = 1; i <= 7; i++) {
			boostHtml += `
				<div id="BoostSlotWrap${i}" class="flex items-center justify-between py-0.5 px-2 rounded cursor-pointer border transition-colors ${i === 1 ? 'bg-white/10 border-white/20' : 'bg-white/5 border-transparent hover:bg-white/10'}" onclick="selectBoostSlot(${i})">
					<label class="flex items-center gap-2 cursor-pointer" onclick="event.stopPropagation()">
						<input type="checkbox" id="SlotActive${i}" data-section="BoostBar" class="config-sync">
						<span class="text-[11px] font-medium text-gray-200">Slot ${i}</span>
					</label>
					<input type="number" id="SlotTimer${i}" data-section="BoostBar" placeholder="s" class="config-sync bg-black/60 border border-white/10 rounded px-1.5 py-0.5 w-12 text-center text-[10px] outline-none focus:border-[#504099]" onclick="event.stopPropagation()">
				</div>
			`;
		}
		boostContainer.innerHTML = boostHtml;
	}

	const modesContainer = document.getElementById('BoostBarModesContainer');
	if (modesContainer) {
		let modesHtml = '';
		availableModes.forEach(mode => {
			modesHtml += `
				<label class="flex items-center gap-2 cursor-pointer">
					<input type="checkbox" id="chkMode_${mode.replace(/\s+/g, '')}" value="${mode}" onclick="toggleBoostMode('${mode}')">
					<span class="text-xs text-gray-300">${mode}</span>
				</label>
			`;
		});
		modesContainer.innerHTML = modesHtml;
	}

	attachConfigListeners();
	if (window.chrome && window.chrome.webview) {
		window.chrome.webview.hostObjects.ahkReady.func();
	}
});

function changeTab(ele) {
	let active = document.getElementsByClassName("active")[0].id;
	if (active == ele.id) return;
	document.getElementById(active).classList.remove("active");
	ele.classList.add("active");
	const Old = document.getElementById(active + "Tab")
	Old.classList.remove("fade-in", 'flex');
	Old.classList.add("hidden");
	const New = document.getElementById(ele.id + "Tab")
	New.classList.remove("hidden");
	New.classList.add("fade-in", 'flex');
}

function ahkAction(actionName) {
	if (window.chrome && window.chrome.webview) {
		window.chrome.webview.hostObjects.ahk.Action(actionName);
	}
}

function showNewProfileModal() {
	document.getElementById('ModalOverlay').classList.replace('hidden', 'flex');
	document.getElementById('NewProfileModal').classList.replace('hidden', 'flex');
	const input = document.getElementById('NewProfileInput');
	input.value = '';
	input.focus();
}

function showDeleteProfileModal() {
	const currentProfile = document.getElementById('PresetDDL').value;
	if (currentProfile === 'config' || currentProfile === '') {
		return;
	}
	document.getElementById('DeleteProfileName').innerText = currentProfile;
	document.getElementById('ModalOverlay').classList.replace('hidden', 'flex');
	document.getElementById('DeleteProfileModal').classList.replace('hidden', 'flex');
}

function hideModals() {
	document.getElementById('ModalOverlay').classList.replace('flex', 'hidden');
	document.getElementById('DeleteProfileModal').classList.replace('flex', 'hidden');
	document.getElementById('NewProfileModal').classList.replace('flex', 'hidden');
	const logModal = document.getElementById('MessageLogModal');
	if(logModal) logModal.classList.replace('flex', 'hidden');
}

function submitNewProfile() {
	const name = document.getElementById('NewProfileInput').value.trim();
	if (name !== '' && name.toLowerCase() !== 'config') {
		ahkAction('NewPreset|' + name);
		hideModals();
	}
}

function submitDeleteProfile() {
	const name = document.getElementById('PresetDDL').value;
	ahkAction('DeletePreset|' + name);
	hideModals();
}

function selectBoostSlot(index) {
	selectedBoostSlot = index;
	document.getElementById('lbl_SelectedSlotModes').innerText = 'Editing Slot ' + index;
	for (let i = 1; i <= 7; i++) {
		const wrap = document.getElementById('BoostSlotWrap' + i);
		if (wrap) {
			if (i === index) {
				wrap.classList.replace('bg-white/5', 'bg-white/10');
				wrap.classList.replace('border-transparent', 'border-white/20');
			} else {
				wrap.classList.replace('bg-white/10', 'bg-white/5');
				wrap.classList.replace('border-white/20', 'border-transparent');
			}
		}
	}
	refreshModeCheckboxes();
}

function refreshModeCheckboxes() {
	const currentModesStr = boostSlotModes[selectedBoostSlot] || "";
	const currentModesArr = currentModesStr.split('|').filter(Boolean);

	availableModes.forEach(mode => {
		const chk = document.getElementById('chkMode_' + mode.replace(/\s+/g, ''));
		if (chk) {
			chk.checked = currentModesArr.includes(mode);
		}
	})
}

function toggleBoostMode(mode) {
	let currentModesStr = boostSlotModes[selectedBoostSlot] || "";
	let currentModesArr = currentModesStr.split('|').filter(Boolean);

	if (currentModesArr.includes(mode)) {
		currentModesArr = currentModesArr.filter(m => m !== mode);
	} else {
		currentModesArr.push(mode);
	}

	const newStr = currentModesArr.join('|');
	boostSlotModes[selectedBoostSlot] = newStr;
	if (window.chrome && window.chrome.webview) {
		window.chrome.webview.hostObjects.ahkChangeSetting.func(newStr, "BoostBar", "SlotMode" + selectedBoostSlot);
	}
}

function generateChannel() {
	const part1 = Math.floor(Math.random() * 90000000 + 10000000);
	const part2 = Math.floor(Math.random() * 90000000 + 10000000);
	const name = "K" + part1 + "X" + part2;

	const input = document.getElementById('DweetName');
	input.value = name;

	if (window.chrome && window.chrome.webview) {
		window.chrome.webview.hostObjects.ahkChangeSetting.func(name, "Communicator", "DweetName");
	}
}

function copyChannel(btn) {
	const input = document.getElementById('DweetName');
	navigator.clipboard.writeText(input.value);
	const originalText = btn.innerText;
	btn.innerText = "Copied!";
	btn.classList.add('text-green-400');
	setTimeout(() => {
		btn.innerText = originalText;
		btn.classList.remove('text-green-400');
	}, 750);
}

async function pasteChannel(btn) {
	try {
		const text = await navigator.clipboard.readText();
		if (text && text.trim() !== '') {
			const input = document.getElementById('DweetName');
			input.value = text.trim();
			
			if (window.chrome && window.chrome.webview) {
				window.chrome.webview.hostObjects.ahkChangeSetting.func(input.value, "Communicator", "DweetName");
			}
			const originalText = btn.innerText;
			btn.innerText = "Pasted!";
			btn.classList.add('text-green-400');
			setTimeout(() => {
				btn.innerText = originalText;
				btn.classList.remove('text-green-400');
			}, 1500);
		}
	} catch (err) {
		console.error("Failed to read clipboard contents: ", err);
	}
}

function updateCommsIndicator() {
	const commsEnabled = document.getElementById('CommunicationEnabled')?.checked;
	if (!commsEnabled) {
		setCommsUI('Disabled');
	} else {
		setCommsUI('Not Connected');
	}
}

function setCommsUI(state, username = "") {
	const light = document.getElementById('BoostBar_CommsLight');
	const text = document.getElementById('BoostBar_CommsText');
	if (!light || !text) return;
	text.classList.remove('text-gray-400', 'text-gray-200', 'text-[#974EC2]', 'text-amber-400');
	if (state === 'Disabled') {
		light.className = "w-1.5 h-1.5 rounded-full bg-red-500 shadow-[0_0_5px_rgba(239,68,68,0.8)] transition-colors duration-300";
		text.innerText = "Comms: Disabled";
		text.classList.add('text-gray-400');
	} 
	else if (state === 'Not Connected') {
		light.className = "w-1.5 h-1.5 rounded-full bg-amber-500 shadow-[0_0_5px_rgba(245,158,11,0.8)] transition-colors duration-300";
		text.innerText = "Not Connected";
		text.classList.add('text-amber-400');
	} 
	else if (state === 'Connected') {
		light.className = "w-1.5 h-1.5 rounded-full bg-[#974EC2] shadow-[0_0_5px_rgba(151,78,194,0.8)] transition-colors duration-300";
		text.innerText = username ? `Connected: ${username}` : "Comms: Connected";
		text.classList.add('text-[#974EC2]');
	}
}

function addMessageLog(sender, channel, action) {
	const container = document.getElementById('MessageLogContainer');
	if (!container) return;

	if (container.innerHTML.includes("Waiting for messages")) {
		container.innerHTML = '';
	}
	const time = new Date().toLocaleTimeString('en-US', { hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit" });
	const logEntry = document.createElement('div');
	logEntry.className = "flex gap-2 text-gray-300 border-b border-white/5 pb-1 shrink-0";
	logEntry.innerHTML = `<span class="text-gray-500">[${time}]</span> <span class="text-[#974EC2] font-bold">${sender}</span> <span class="text-gray-400">${channel}:</span> <span class="text-white">${action}</span>`;
	container.prepend(logEntry);
	if (container.childElementCount > 20) {
		container.removeChild(container.lastChild);
	}
}

async function drag() {
	await window.chrome.webview.hostObjects.drag.func();
}
async function minimizeWindow() {
	await window.chrome.webview.hostObjects.minimizeWindow.func();
}
async function closeWindow() {
	await window.chrome.webview.hostObjects.closeWindow.func();
}
async function openLink(url) {
	if (window.chrome && window.chrome.webview) {
		await window.chrome.webview.hostObjects.ahk.OpenLink(url);
	}
}
window.addEventListener('keydown', function(e) {
	if (e.key === 'F7' || e.key === 'F5') {
		e.preventDefault();
	}
})