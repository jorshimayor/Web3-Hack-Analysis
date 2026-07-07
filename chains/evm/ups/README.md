# UtopiaSphere (UPS) Token Hack Analysis 🕵️‍♂️

## 📋 Executive Summary

This repository is an assessment submission to Guild Academy. It contains a security analysis of the UtopiaSphere (UPS) token hack that occurred on the Binance Smart Chain (BSC). The exploit resulted in significant financial losses due to a critical vulnerability in the token's transfer mechanism combined with a flawed burn function.

**Key Findings:**
- **Vulnerability Type**: Logic Error in Token Transfer Restrictions
- **Impact**: Token pair drainage and market manipulation
- **Root Cause**: Inconsistent transfer validation allowing exploitation of burn mechanism
- **Status**: Post-exploit analysis (pair already drained)

---

## 🎯 What is UtopiaSphere (UPS)?

UtopiaSphere was a BEP-20 token deployed on Binance Smart Chain with the following features:
- **Symbol**: UPS
- **Network**: Binance Smart Chain (BSC)
- **Pair**: UPS/USDT on PancakeSwap
- **Special Features**: Anti-dump mechanism with token burning on sells

---

## 🚨 The Vulnerability Explained

### 🔍 The Core Problem

The UPS token contract contained a critical flaw in its `_update` function (the internal transfer mechanism). Let's break this down:

#### Normal Token Behavior Expected:
1. ✅ Users can buy UPS with USDT
2. ✅ Users can sell UPS for USDT  
3. ✅ Anti-dump mechanism burns tokens on large sells

#### What Actually Happened:
1. ❌ The contract blocked ALL transfers FROM the PancakeSwap pair
2. ✅ But allowed transfers TO the pair (deposits)
3. 🔥 This created a "token trap" where tokens could enter but not exit normally

### 📝 Code Analysis

Here's the problematic code in the UPS contract:

```solidity
function _update(address from, address to, uint256 amount) internal virtual override {
    if (
        inSwapAndLiquify ||
        whiteMap[from] ||
        whiteMap[to] ||
        !(from == pairAddress || to == pairAddress)
    ) {
        // ✅ Normal transfers allowed
        super._update(from, to, amount);
    } else if (from == pairAddress) {
        // ❌ CRITICAL BUG: This prevents ALL swaps from USDT to UPS!
        revert ERC20InvalidSender(from);
    } else if (to == pairAddress) {
        // 🔥 This is where the exploit happens
        uint256 fee = (amount * 5) / 100;
        if (!inSwapAndLiquify) {
            _swapBurn(amount - fee);  // 95% of tokens get burned!
        }
        // ... rest of the logic
    }
}
```

### 🎭 The Exploit Mechanism

The attacker exploited this by:

1. **Initial Setup**: Obtained large amounts of USDT (likely through flash loans)

2. **Token Acquisition**: Despite the transfer restriction, found a way to acquire UPS tokens (possibly through:
   - Direct contract interaction
   - Exploiting whitelist mechanisms
   - Using the contract owner privileges)

3. **Pair Manipulation**: Sold UPS tokens to trigger the `_swapBurn` function:
   - 95% of sold tokens got burned 🔥
   - This dramatically reduced the UPS supply in the pair
   - Created massive price imbalance

4. **Drainage**: With most UPS tokens burned, the remaining tokens became extremely valuable relative to USDT, allowing drainage of the pair's USDT reserves

---

## 📊 Impact Analysis

### Current State (Post-Exploit):
```
🏦 Pair Reserves:
├── USDT: 7 wei (≈ $0.000000000000000007)
├── UPS: 1,431,260,335,164,579,589,772,442 tokens
└── Price: $0 per UPS (no USDT left to trade)
```

### Financial Impact:
- **USDT Drained**: Nearly complete drainage of pair reserves
- **Token Price**: Collapsed to effectively $0
- **Liquidity**: Completely destroyed
- **Investors**: Total loss for UPS holders

---

## 🛠️ Technical Setup

This analysis uses Foundry for blockchain testing and simulation.

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation
```bash
git clone https://github.com/jorshimayor/utopiasphere-hack-analysis
cd utopiasphere-hack-analysis
forge install
```

### Running the Analysis
```bash
# Build the project
forge build

# Run the exploit simulation
forge test --match-test testExploit -vv

# Run with detailed traces
forge test --match-test testExploit -vvv
```

---

## 🎓 Learning Points for Developers

### ❌ What Went Wrong:

1. **Inconsistent Access Controls**: 
   - Transfer restrictions were applied inconsistently
   - Pair contract wasn't properly whitelisted

2. **Dangerous Burn Mechanism**:
   - Burning 95% of tokens on sells created extreme price volatility
   - No protection against manipulation

3. **Lack of Circuit Breakers**:
   - No maximum transaction limits
   - No pause functionality for emergencies

4. **Insufficient Testing**:
   - Edge cases weren't properly tested
   - Integration with DEX mechanics not validated

## ⚖️ Disclaimer

This analysis is for educational purposes only. The code and findings should not be used for malicious purposes. Always conduct security research responsibly and within legal boundaries.

---

## 🤝 Contributing

Found an issue or want to contribute to the analysis? 
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with your improvements

---

## 📞 Contact

For questions about this analysis or security research collaborations:
- GitHub: [@jorshimayor](https://github.com/jorshimayor)

---

*Remember: In DeFi, your security is your responsibility. Always DYOR (Do Your Own Research)!* 🛡️