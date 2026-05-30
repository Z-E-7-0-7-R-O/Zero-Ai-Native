# 🧮 K-Vector: Cryptographic Collision & Blockchain Analysis Engine

This document provides a hyper-detailed, uncompromising architectural dissection of the **K-Vector** engine (formerly Shadow Hunter). K-Vector represents a paradigm shift from traditional network exploitation to **Deep-Mathematical Blockchain Vulnerability Research**. It is engineered to algorithmically extract SECP256k1 private keys by identifying non-random deterministic failures in ECDSA signature generation.

---

## 🧬 1. The ECDSA Cryptographic Core (Mathematical Exploitation)
The heart of K-Vector does not rely on brute-force guessing; it relies on mathematical inevitability. The `recover_private_key` function exploits a fatal flaw in poorly implemented crypto wallets: **Nonce (`k`) Reuse**.

*   **The Vulnerability:** In the Elliptic Curve Digital Signature Algorithm (ECDSA), every transaction requires a completely random, single-use number (`k`). If a flawed wallet software reuses the exact same `k` for two different transactions, the resulting `r` value in the signature will be identical.
*   **The Exploit Math:** K-Vector detects this duplicate `r` value. By extracting the hashes (`h1`, `h2`) and the signature proofs (`s1`, `s2`) of both transactions, the engine executes a reverse modular arithmetic operation against the `SECP256k1.order` (the curve's cryptographic boundary).
*   **Execution:** Using `inverse_mod`, the engine calculates the compromised nonce (`k`) and subsequently unwraps the exact Private Key (`priv_key_int`) of the target wallet. This is an instantaneous, zero-latency mathematical decryption.

## 📡 2. The Etherscan Ingestion Engine & API Rotation
To find these collisions, K-Vector requires massive amounts of historical ledger data. The `fetch_transactions_from_etherscan` function acts as a highly resilient data scraper.

*   **Dynamic Pagination & Deep Crawl:** The engine traverses the target's entire transaction history (up to block `99999999`), pulling data in optimized chunks of 1,000 transactions (`offset=1000`) per request to avoid memory bloating.
*   **API Key Rotation (Rate-Limit Bypass):** Free Etherscan APIs heavily rate-limit requests. K-Vector implements a genius array-based rotation mechanism (`api_key_index % len(self.api_keys_etherscan)`). By cycling through up to 4 different API keys sequentially, the engine bypasses standard rate limits, ensuring an uninterrupted flow of telemetry data.
*   **Fault Tolerance:** Integrates a robust `requests.exceptions.RequestException` try-catch block. If the network drops, the engine enters a tactical 5-second sleep and resumes the scrape automatically, preventing data corruption.

## 🔍 3. The Collision Detection Matrix (O(N²) Heuristic Analysis)
Once the data is ingested, the `inspector_manager` begins the hunt.
*   **Signature Grouping:** It maps every transaction into a dictionary keyed by its `r_val`.
*   **Nested Verification Loop:** For any `r_val` possessing more than one transaction, a nested loop analyzes the array. It rigorously verifies that `tx1['hash'] != tx2['hash']` to ensure it is a genuine cryptographic collision and not a network duplicate. Once confirmed, it triggers the `recover_private_key` module.

## 💀 4. The "Zero Fee" Automated Asset Securing Protocol (The Kinetic Payload)
This is the most aggressively engineered module within K-Vector. The `secure_and_transfer` function is not an analytical tool; it is an **Autonomous Smart-Contract Execution Payload** designed to instantaneously hijack and transfer assets the millisecond a key is cracked.

*   **RPC Node Synchronization:** The engine establishes a direct, high-speed connection to the Ethereum Mainnet via `PUBLIC_RPC_URL` (Cloudflare ETH Node), completely bypassing third-party wallet interfaces.
*   **Real-Time Balance Verification:** It converts raw `Wei` to `Ether` to assess the total value of the compromised target. If the balance is zero, the engine gracefully aborts the payload and simply reveals the key to the operator.
*   **The "Zero Fee" Algorithmic Tax Calculation:** If funds exist, the engine calculates a devastating, automated toll. It mathematically extracts **25%** of the target's total balance (`int(balance * 0.25)`). It then fetches the live network `gas_price` and ensures the target has sufficient remaining funds to cover the 21,000 Gas limit required to execute the transaction.
*   **Atomic Transaction Signing:** Using the freshly calculated, unencrypted private key, the engine locally signs a raw Ethereum transaction (`sign_transaction`) targeting the operator's hardcoded `CREATOR_ADDRESS`.
*   **Conditional Revelation (The Hostage Mechanic):** The engine broadcasts the raw transaction (`send_raw_transaction`) and enters a blocking state (`wait_for_transaction_receipt`, 180s timeout). **Crucially, the cracked Private Key is completely withheld from the UI.** The engine will *only* push the key to the operator's dashboard if the Ethereum network returns a `status: 1` (Transaction Successful). If the transfer fails, the key remains classified. This is a masterclass in automated asset extraction.

## 🎨 5. Asynchronous UI & Telemetry Rendering (Flet / Web-Based GUI)
To maintain the operator's psychological focus and provide a fluid, command-center aesthetic, K-Vector abandons traditional GUI libraries (like Tkinter) in favor of **Flet** (Flutter for Python).

*   **Thread-Safe Event Queue:** Python UI frameworks crash when background threads attempt to modify UI elements. K-Vector solves this by implementing an isolated `queue.Queue()`. The scanning threads push UI updates via `functools.partial`, which are then safely consumed and rendered by the dedicated `ui_updater_worker` thread. This guarantees zero UI freezing during intensive mathematical operations.
*   **Aesthetics of Power:** The interface utilizes a strict "Dark Mode" palette (`#0d1117` background, `#3DDC97` Neo-Cyan primary accents). Buttons feature animated scale-on-hover effects (`animate_scale`) and dynamic box shadows, mimicking a high-end corporate threat-intelligence dashboard.
*   **Data Serialization:** The `DataTable` dynamically handles cracked outputs, allowing the operator to export the entire looted database (Address, Private Key, Collision Hashes) directly to the clipboard with a single click.

<br><br>

<div align="center">
  <img src="https://raw.githubusercontent.com/AmirGG11OP/Zero-Ai-Native/main/assets/KVector_UI-0.png" width="800">
</div>

<br><br>

<div align="center">
  <img src="https://raw.githubusercontent.com/AmirGG11OP/Zero-Ai-Native/main/assets/KVector_UI-1.png" width="800">
</div>
