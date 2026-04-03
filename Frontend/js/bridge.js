const featureCheckboxes = [
	"WarnsEnabled", "BoostBarEnabled", "TrackerEnabled",
	"MagnifierEnabled", "AltMacroEnabled", "StatMonitorEnabled",
	"KeyAlignmentEnabled"
];

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
});

function attachConfigListeners() {
	const inputs = document.querySelectorAll('.config-sync');
	inputs.forEach(input => {
		if (!input.dataset.listenerAttached) {
			input.addEventListener('change', (e) => {
				const ele = e.target;
				const section = ele.getAttribute('data-section');
				const key = ele.id; 
				let value;
				
				if (ele.type === 'checkbox') {
					value = ele.checked ? 1 : 0; 
				} else if (ele.type === 'number') {
					value = parseFloat(ele.value);
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
	updateCurrentlyToggled();
}

document.addEventListener('DOMContentLoaded', function () {
	const warnItems = [
		{ key: "Precise", name: "Precision", unit: "s" },
		{ key: "Smoothie", name: "Super Smoothie", unit: "s" },
		{ key: "Gummy", name: "Gummy Star", unit: "x" },
		{ key: "Pop", name: "Pop Star", unit: "x" },
		{ key: "Scorch", name: "Scorching Star", unit: "x" },
		{ key: "Shower", name: "Star Shower", unit: "x" },
		{ key: "Morph", name: "Gummy Morph", unit: "x" },
		{ key: "Baller", name: "Gummyballer", unit: "x" },
		{ key: "Combo", name: "Coconut Combo", unit: "x" }
	];
	const warnContainer = document.getElementById('WarningsContainer');
if (warnContainer) {
		let html = '';
		warnItems.forEach(item => {
			html += `
				<div class="flex flex-col bg-white/5 rounded-lg border border-white/5 shadow-sm overflow-hidden mb-2 transition-all">
					
					<div class="grid grid-cols-12 gap-4 items-center p-2 px-3">
						<div class="col-span-5 flex items-center gap-3">
							<input type="checkbox" id="${item.key}_Enabled" data-section="Warns" class="config-sync">
							<span class="text-sm font-medium text-gray-200">${item.name}</span>
						</div>
						<div class="col-span-4 flex items-center justify-center gap-2">
							<input type="number" id="${item.key}_Threshold" data-section="Warns" class="config-sync bg-black/60 border border-white/10 rounded px-2 py-1 w-16 text-center text-xs outline-none focus:border-[#504099] transition">
							<span class="text-[10px] text-gray-500">/ ??${item.unit}</span>
						</div>
						<div class="col-span-3 flex justify-center">
							<button onclick="document.getElementById('settings_${item.key}').classList.toggle('hidden')" class="bg-[#313865] hover:bg-[#504099] text-white text-[10px] uppercase tracking-wider px-3 py-1 rounded transition shadow-sm w-full">
								Settings ⏷
							</button>
						</div>
					</div>

					<div id="settings_${item.key}" class="hidden flex-col gap-3 p-3 bg-black/30 border-t border-white/5">
						
						<div class="flex items-center justify-between gap-4">
							<div class="flex items-center gap-2 flex-1">
								<span class="text-xs text-gray-400 font-bold uppercase tracking-wider">Vol:</span>
								<input type="range" id="${item.key}_Volume" data-section="Warns" min="0" max="100" class="config-sync flex-1 accent-[#504099]" oninput="document.getElementById('lbl_${item.key}_Volume').innerText = this.value">
								<span id="lbl_${item.key}_Volume" class="text-xs text-gray-300 w-6 text-right">25</span><span class="text-xs text-gray-500">%</span>
							</div>
							
							<label class="flex items-center gap-2">
								<input type="checkbox" id="${item.key}_PlayOnce" data-section="Warns" class="config-sync">
								<span class="text-xs text-gray-400 font-bold uppercase tracking-wider">Play Once</span>
							</label>
						</div>

						<div class="flex items-center gap-2">
							<input type="text" id="${item.key}_SoundFile" data-section="Warns" readonly class="config-sync bg-black/60 border border-white/10 rounded px-2 py-1.5 flex-1 text-[10px] text-gray-500 outline-none truncate" title="Audio File Path">
							
							<button onclick="ahkAction('BrowseSound|${item.key}')" class="bg-white/10 hover:bg-white/20 text-gray-300 text-[10px] uppercase tracking-wider px-3 py-1.5 rounded transition">Browse</button>
							<button onclick="ahkAction('TestSound|${item.key}')" class="bg-[#313865] hover:bg-[#504099] text-white text-[10px] uppercase tracking-wider px-3 py-1.5 rounded transition">Test</button>
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
				<div class="flex items-center justify-between bg-white/5 p-2 rounded px-3 hover:bg-white/10 transition">
					<label class="flex items-center gap-3 cursor-pointer">
						<input type="checkbox" id="SlotActive${i}" data-section="BoostBar" class="config-sync"></input>
						<span class="text-sm text-gray-300">Slot ${i}</span>
					</label>
					<input type="number" id="SlotTimer${i}" data-section="BoostBar" placeholder="ms" class="config-sync bg-black/40 border border-white/10 rounded px-2 py-1 w-20 text-center text-xs outline-none hidden"></input>
				</div>
			`;
		}
		boostContainer.innerHTML = boostHtml;
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