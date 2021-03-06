// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721, ERC721TokenReceiver} from "../../IERC721.sol";

contract ERC721User is ERC721TokenReceiver {
    ERC721 token;

    constructor(address _tokenAddress) {
        token = ERC721(_tokenAddress);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function approve(address spender, uint256 tokenId) public virtual {
        token.approve(spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        token.setApprovalForAll(operator, approved);
    }

    function getApproved(uint tokenId) public virtual returns (address) {
        return token.getApproved(tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        token.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        token.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        token.safeTransferFrom(from, to, tokenId, data);
    }
}

