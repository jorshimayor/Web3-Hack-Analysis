// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ERC20} from "./token/ERC20.sol";
import {ERC20Burnable} from "./token/ERC20Burnable.sol";
import {Ownable} from "./access/Ownable.sol";
import {ISwapPair} from "./interfaces/ISwapPair.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {ISwapFactory} from "./interfaces/ISwapFactory.sol";

contract UPS is ERC20Burnable, Ownable {
    ISwapRouter public swapRouter;
    address public usdtAddress;
    address public pairAddress;
    uint256 public sellRate;

    mapping(address => bool) public whiteMap;
    address[] public nodeList;

    bool inSwapAndLiquify;
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() ERC20("UtopiaSphere", "UPS") Ownable(_msgSender()) {
        sellRate = 5;
        if (block.chainid == 56) {
            usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
            swapRouter = ISwapRouter(
                0x10ED43C718714eb63d5aA57B78B54704E256024E
            );
        } else {
            usdtAddress = 0x311bb5a90eA517529F6CE7e2aE19E9390ce35a0C;
            swapRouter = ISwapRouter(
                0xD99D1c33F9fC3444f8101754aBC46c52416550D1
            );
        }
        pairAddress = ISwapFactory(swapRouter.factory()).createPair(
            usdtAddress,
            address(this)
        );
        whiteMap[_msgSender()] = true;
        _mint(_msgSender(), 420 * 1e8 ether);
    }

    function _swapBurn(uint amount) private lockTheSwap {
        super._burn(pairAddress, amount);
        ISwapPair(pairAddress).sync();
    }

    function setRate(uint256 _sellRate) public onlyOwner {
        sellRate = _sellRate;
    }

    function setNodeList(address[] memory list) public onlyOwner {
        nodeList = list;
    }

    function setWhiteMap(address[] memory users, bool value) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whiteMap[users[i]] = value;
        }
    }

    function getPrice() public view returns (uint256 price) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdtAddress;
        (uint256 reserve1, uint256 reserve2, ) = ISwapPair(pairAddress)
            .getReserves();
        if (reserve1 == 0 || reserve2 == 0) {
            price = 0;
        } else {
            price = swapRouter.getAmountsOut(10 ** decimals(), path)[1];
        }
    }

    function transfer(
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        if (to == address(0)) {
            _burn(_msgSender(), value);
            return true;
        } else {
            super._transfer(_msgSender(), to, value);
            return true;
        }
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (
            inSwapAndLiquify ||
            whiteMap[from] ||
            whiteMap[to] ||
            !(from == pairAddress || to == pairAddress)
        ) {
            super._update(from, to, amount);
        } else if (from == pairAddress) {
            revert ERC20InvalidSender(from);
        } else if (to == pairAddress) {
            uint256 fee = (amount * 5) / 100;
            if (!inSwapAndLiquify) {
                _swapBurn(amount - fee);
            }
            if (nodeList.length > 0) {
                uint256 every = fee / nodeList.length;
                for (uint256 i = 0; i < nodeList.length; i++) {
                    super._update(from, nodeList[i], every);
                }
            } else {
                _burn(from, fee);
            }
            super._update(from, to, amount - fee);
        }
    }
}
