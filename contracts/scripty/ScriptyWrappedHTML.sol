// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

///////////////////////////////////////////////////////////
// ░██████╗░█████╗░██████╗░██╗██████╗░████████╗██╗░░░██╗ //
// ██╔════╝██╔══██╗██╔══██╗██║██╔══██╗╚══██╔══╝╚██╗░██╔╝ //
// ╚█████╗░██║░░╚═╝██████╔╝██║██████╔╝░░░██║░░░░╚████╔╝░ //
// ░╚═══██╗██║░░██╗██╔══██╗██║██╔═══╝░░░░██║░░░░░╚██╔╝░░ //
// ██████╔╝╚█████╔╝██║░░██║██║██║░░░░░░░░██║░░░░░░██║░░░ //
// ╚═════╝░░╚════╝░╚═╝░░╚═╝╚═╝╚═╝░░░░░░░░╚═╝░░░░░░╚═╝░░░ //
///////////////////////////////////////////////////////////
//░░░░░░░░░░░░░░░░░    WRAPPED HTML    ░░░░░░░░░░░░░░░░░░//
///////////////////////////////////////////////////////////

import "./ScriptyCore.sol";
import "./interfaces/IScriptyWrappedHTML.sol";

contract ScriptyWrappedHTML is IScriptyWrappedHTML, ScriptyCore {
    using DynamicBuffer for bytes;

    // =============================================================
    //                      RAW HTML GETTERS
    // =============================================================

    /**
     * @notice Get requested scripts housed in <body> with custom wrappers
     * @dev Your requested scripts are returned in the following format:
     *      <html>
     *          <head>
     *              [wrapPrefix[0]]{headTagRequest[0]}[wrapSuffix[0]]
     *              [wrapPrefix[1]]{headTagRequest[1]}[wrapSuffix[1]]
     *              ...
     *              [wrapPrefix[n]]{headTagRequest[n]}[wrapSuffix[n]]
     *          </head>
     *          <body style='margin:0;'>
     *              [wrapPrefix[0]]{request[0]}[wrapSuffix[0]]
     *              [wrapPrefix[1]]{request[1]}[wrapSuffix[1]]
     *              ...
     *              [wrapPrefix[n]]{request[n]}[wrapSuffix[n]]
     *          </body>
     *      </html>
     * @param headRequests - Array of HeadRequests
     * @param scriptRequests - Array of ScriptRequests
     * @return Full html wrapped scripts
     */
    function getHTMLWrapped(
        HeadRequest[] calldata headRequests,
        ScriptRequest[] memory scriptRequests
    ) public view returns (bytes memory) {
        uint256 scriptBufferSize = buildWrappedScriptsAndGetSize(
            scriptRequests
        );

        bytes memory htmlFile = DynamicBuffer.allocate(
            getHTMLWrapBufferSize(headRequests, scriptBufferSize)
        );

        // <html>
        htmlFile.appendSafe(HTML_OPEN_RAW);

        // <head>
        htmlFile.appendSafe(HEAD_OPEN_RAW);
        if (headRequests.length > 0) {
            _appendHeadRequests(htmlFile, headRequests);
        }
        htmlFile.appendSafe(HEAD_CLOSE_RAW);
        // </head>

        // <body>
        htmlFile.appendSafe(BODY_OPEN_RAW);
        if (scriptRequests.length > 0) {
            _appendScriptRequests(htmlFile, scriptRequests, true, false);
        }
        htmlFile.appendSafe(HTML_BODY_CLOSED_RAW);
        // </body>
        // </html>

        return htmlFile;
    }

    function getHTMLWrapBufferSize(
        HeadRequest[] calldata headRequests,
        uint256 scriptSize
    ) public pure returns (uint256 size) {
        unchecked {
            // <html><head></head><body></body></html>
            size = URLS_RAW_BYTES;
            size += getBufferSizeForHeadTags(headRequests);
            size += scriptSize;
        }
    }

    // =============================================================
    //                      ENCODED HTML GETTERS
    // =============================================================

    /**
     * @notice Get {getHTMLWrapped} and base64 encode it
     * @param scriptRequests - Array of WrappedScriptRequests
     * @return Full html wrapped scripts, base64 encoded
     */
    function getEncodedHTMLWrapped(
        HeadRequest[] calldata headRequests,
        ScriptRequest[] calldata scriptRequests
    ) public view returns (bytes memory) {
        unchecked {
            bytes memory rawHTML = getHTMLWrapped(headRequests, scriptRequests);

            uint256 sizeForEncoding = _sizeForBase64Encoding(rawHTML.length);
            sizeForEncoding += HTML_BASE64_DATA_URI_BYTES;

            bytes memory htmlFile = DynamicBuffer.allocate(sizeForEncoding);
            htmlFile.appendSafe("data:text/html;base64,");
            htmlFile.appendSafeBase64(rawHTML, false, false);
            return htmlFile;
        }
    }

    // =============================================================
    //                      STRING UTILITIES
    // =============================================================

    /**
     * @notice Convert {getHTMLWrapped} output to a string
     * @param scriptRequests - Array of WrappedScriptRequests
     * @return {getHTMLWrapped} as a string
     */
    function getHTMLWrappedString(
        HeadRequest[] calldata headRequests,
        ScriptRequest[] calldata scriptRequests
    ) public view returns (string memory) {
        return string(getHTMLWrapped(headRequests, scriptRequests));
    }

    /**
     * @notice Convert {getEncodedHTMLWrapped} output to a string
     * @param scriptRequests - Array of WrappedScriptRequests
     * @return {getEncodedHTMLWrapped} as a string
     */
    function getEncodedHTMLWrappedString(
        HeadRequest[] calldata headRequests,
        ScriptRequest[] calldata scriptRequests
    ) public view returns (string memory) {
        return string(getEncodedHTMLWrapped(headRequests, scriptRequests));
    }
}