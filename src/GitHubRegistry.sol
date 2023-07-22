// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "sismo-connect-solidity/SismoConnectLib.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GitHubRegistry is ERC721, SismoConnect, Ownable {
    using SismoConnectHelper for SismoConnectVerifiedResult;
    event GitHubIdRegistered(uint256 indexed githubId);
    error InvalidInputLegnths();

    // string of uint256 githubId
    mapping(string githubId => bool isRegistered) private _registered;
    mapping(string githubId => string githubHandle) private _githubHandles;

    constructor()
        ERC721("GitHubRegistry", "GHR")
        SismoConnect(buildConfig(0x5ed8de79b8920ed9cc7e6a25301a39d4, true))
    {
        _transferOwnership(0x061060a65146b3265C62fC8f3AE977c9B27260fF);
    }

    function register(bytes memory response, address to) external {
        SismoConnectVerifiedResult memory result = verify({
            responseBytes: response,
            auth: buildAuth(AuthType.GITHUB),
            signature: buildSignature({message: abi.encode(to)})
        });

        // create a mask that has all but the first 16 bits set to 1
        // start at 160 bits, because the userId is like an address, and we want to mask off the first 16 bits
        uint256 mask = (1 << (160 - 16)) - 1;
        uint256 githubId = (result.getUserId(AuthType.GITHUB)) & mask; // mask off the unwanted bits
        string memory githubIdAsString = string(abi.encodePacked(githubId));

        // store without doing any transformations since we want to be able to look up by githubId
        _registered[githubIdAsString] = true;
        _mint(to, githubId);

        emit GitHubIdRegistered(githubId);
    }

    function computeNFTs(
        uint256[] memory ids,
        string[] memory githubHandles
    ) external onlyOwner {
        if (ids.length != githubHandles.length) {
            revert InvalidInputLegnths();
        }

        for (uint256 i = 0; i < ids.length; i++) {
            // only compute NFTs for registered githubIds
            string memory githubIdAsString = string(
                abi.encodePacked(uint256(ids[i]))
            );
            if (
                _registered[githubIdAsString] &&
                keccak256(abi.encodePacked(_githubHandles[githubIdAsString])) ==
                keccak256(abi.encodePacked(""))
            ) {
                _githubHandles[githubIdAsString] = githubHandles[i];
            }
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _computeSVG(_githubHandles[string(abi.encodePacked(tokenId))]);
    }

    function _computeSVG(
        string memory githubHandle
    ) private pure returns (string memory) {
        string
            memory svgPart1 = '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" style="background-color:black;"><text x="35%" y="85%" dominant-baseline="middle" text-anchor="middle" fill="white" font-size="50" font-family="Verdana">@';
        string
            memory svgPart2 = '</text><image href="https://qph.cf2.quoracdn.net/main-qimg-729a22aba98d1235fdce4883accaf81e" height="300" width="300" y="0" x="90"/></svg>';
        bytes memory image = abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(
                bytes(abi.encodePacked(svgPart1, githubHandle, svgPart2))
            )
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"GitHub Handles", "image":"',
                                image,
                                unicode'", "description": "This NFT is a tokenized GitHub handle."}'
                            )
                        )
                    )
                )
            );
    }
}
