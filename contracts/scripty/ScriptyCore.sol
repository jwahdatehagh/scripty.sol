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
//░░░░░░░░░░░░░░░░░░░░░░    CORE    ░░░░░░░░░░░░░░░░░░░░░//
///////////////////////////////////////////////////////////

/**
  @title A generic HTML builder that fetches and assembles given JS requests.
  @author @0xthedude
  @author @xtremetom

  Special thanks to @cxkoda, @frolic and @dhof
*/

struct HTMLRequest {
    HeadRequest[] headRequests;
    ScriptRequest[] scriptRequests;
}

struct HeadRequest {
    bytes wrapPrefix;
    bytes wrapSuffix;
    bytes scriptContent;
}

struct ScriptRequest {
    string name;
    address contractAddress;
    bytes contractData;
    uint8 wrapType;
    bytes wrapPrefix;
    bytes wrapSuffix;
    bytes scriptContent;
}

import {DynamicBuffer} from "./utils/DynamicBuffer.sol";
import {IScriptyStorage} from "./IScriptyStorage.sol";
import {IContractScript} from "./IContractScript.sol";

contract ScriptyCore {
    using DynamicBuffer for bytes;

    error InvalidRequestsLength();

    // =============================================================
    //                        TAG CONSTANTS
    // =============================================================

    // <html>,
    // raw
    // 6 bytes
    bytes public constant HTML_OPEN_RAW = "<html>";
    // url encoded
    // 10 bytes
    bytes public constant HTML_OPEN_URL_SAFE = "%3Chtml%3E";

    // <head>,
    // raw
    // 6 bytes
    bytes public constant HEAD_OPEN_RAW = "<head>";
    // url encoded
    // 10 bytes
    bytes public constant HEAD_OPEN_URL_SAFE = "%3Chead%3E";

    // </head>,
    // raw
    // 7 bytes
    bytes public constant HEAD_CLOSE_RAW = "</head>";
    // url encoded
    // 13 bytes
    bytes public constant HEAD_CLOSE_URL_SAFE = "%3C%2Fhead%3E";

    // <body>
    // 6 bytes
    bytes public constant BODY_OPEN_RAW = "<body>";
    // url encoded
    // 10 bytes
    bytes public constant BODY_OPEN_URL_SAFE = "%3Cbody%3E";

    // </body></html>
    // 14 bytes
    bytes public constant HTML_BODY_CLOSED_RAW = "</body></html>";
    // 26 bytes
    bytes public constant HTML_BODY_CLOSED_URL_SAFE =
        "%3C%2Fbody%3E%3C%2Fhtml%3E";

    // <script>,
    // raw
    // 8 bytes
    bytes public constant SCRIPT_OPEN_RAW = "<script>";
    // url encoded
    // 12 bytes
    bytes public constant SCRIPT_OPEN_URL_SAFE = "%3Cscript%3E";

    // </script>,
    // raw
    // 9 bytes
    bytes public constant SCRIPT_CLOSE_RAW = "</script>";
    // url encoded
    // 15 bytes
    bytes public constant SCRIPT_CLOSE_URL_SAFE = "%3C%2Fscript%3E";

    // [RAW]
    // HTML_OPEN + HEAD_OPEN + HEAD_CLOSE + BODY_OPEN + HTML_BODY_CLOSED
    uint256 public constant URLS_RAW_BYTES = 39;

    // [URL_SAFE]
    // HTML_OPEN + HEAD_OPEN + HEAD_CLOSE + BODY_OPEN + HTML_BODY_CLOSED
    uint256 public constant URLS_SAFE_BYTES = 69;

    // [RAW]
    // HTML_OPEN + HTML_CLOSE
    uint256 public constant HTML_RAW_BYTES = 13;

    // [RAW]
    // HEAD_OPEN + HEAD_CLOSE
    uint256 public constant HEAD_RAW_BYTES = 13;

    // [RAW]
    // BODY_OPEN + BODY_CLOSE
    uint256 public constant BODY_RAW_BYTES = 13;

    // All raw
    // HTML_RAW_BYTES + HEAD_RAW_BYTES + BODY_RAW_BYTES
    uint256 public constant RAW_BYTES = 39;

    // [URL_SAFE]
    // HTML_OPEN + HTML_CLOSE
    uint256 public constant HTML_URL_SAFE_BYTES = 23;

    // [URL_SAFE]
    // HEAD_OPEN + HEAD_CLOSE
    uint256 public constant HEAD_URL_SAFE_BYTES = 23;

    // [URL_SAFE]
    // BODY_OPEN + BODY_CLOSE
    uint256 public constant BODY_SAFE_BYTES = 23;

    // All url safe
    // HTML_URL_SAFE_BYTES + HEAD_URL_SAFE_BYTES + BODY_URL_SAFE_BYTES
    // %3Chtml%3E%3Chead%3E%3C%2Fhead%3E%3Cbody%3E%3C%2Fbody%3E%3C%2Fhtml%3E
    uint256 public constant URL_SAFE_BYTES = 69;

    // <script></script>
    uint256 public constant SCRIPT_INLINE_BYTES = 17;

    // data:text/html;base64,
    uint256 public constant HTML_BASE64_DATA_URI_BYTES = 22;

    // =============================================================
    //                           INTERNAL
    // =============================================================

    /**
     * @notice Grab script wrapping based on script type
     * @dev
     *      wrapType: 0:
     *          <script>[SCRIPT]</script>
     *
     *      wrapType: 1:
     *          <script src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 2:
     *          <script type="text/javascript+gzip" src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 3
     *          <script type="text/javascript+png" name="[NAME]" src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 4 or any other:
     *          [wrapPrefix][scriptContent or scriptFromContract][wrapSuffix]
     *
     *      [IMPORTANT NOTE]: The tags `text/javascript+gzip` and `text/javascript+png` are used to identify scripts
     *      during decompression
     *
     * @param request - WrappedScriptRequest data for code
     * @return (prefix, suffix) - Type specific prefix and suffix as a tuple
     */
    function _wrapPrefixAndSuffixFor(
        ScriptRequest memory request
    ) internal pure returns (bytes memory, bytes memory) {
        if (request.wrapType == 0) {
            return ("<script>", "</script>");
        } else if (request.wrapType == 1) {
            return ('<script src="data:text/javascript;base64,', '"></script>');
        } else if (request.wrapType == 2) {
            return (
                '<script type="text/javascript+gzip" src="data:text/javascript;base64,',
                '"></script>'
            );
        } else if (request.wrapType == 3) {
            return (
                '<script type="text/javascript+png" src="data:text/javascript;base64,',
                '"></script>'
            );
        }
        return (request.wrapPrefix, request.wrapSuffix);
    }

    /**
     * @notice Grab URL safe script wrapping based on script type
     * @dev
     *      wrapType: 0:
     *      wrapType: 1:
     *          <script src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 2:
     *          <script type="text/javascript+gzip" src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 3
     *          <script type="text/javascript+png" name="[NAME]" src="data:text/javascript;base64,[SCRIPT]"></script>
     *
     *      wrapType: 4 or any other:
     *          [wrapPrefix][scriptContent or scriptFromContract][wrapSuffix]
     *
     *      [IMPORTANT NOTE]: The tags `text/javascript+gzip` and `text/javascript+png` are used to identify scripts
     *      during decompression
     *
     * @param request - WrappedScriptRequest data for code
     * @return (prefix, suffix) - Type specific prefix and suffix as a tuple
     */
    function _wrapURLSafePrefixAndSuffixFor(
        ScriptRequest memory request
    ) internal pure returns (bytes memory, bytes memory) {
        if (request.wrapType <= 1) {
            // <script src="data:text/javascript;base64,
            // "></script>
            return (
                "%253Cscript%2520src%253D%2522data%253Atext%252Fjavascript%253Bbase64%252C",
                "%2522%253E%253C%252Fscript%253E"
            );
        } else if (request.wrapType == 2) {
            // <script type="text/javascript+gzip" src="data:text/javascript;base64,
            // "></script>
            return (
                "%253Cscript%2520type%253D%2522text%252Fjavascript%252Bgzip%2522%2520src%253D%2522data%253Atext%252Fjavascript%253Bbase64%252C",
                "%2522%253E%253C%252Fscript%253E"
            );
        } else if (request.wrapType == 3) {
            // <script type="text/javascript+png" src="data:text/javascript;base64,
            // "></script>
            return (
                "%253Cscript%2520type%253D%2522text%252Fjavascript%252Bpng%2522%2520src%253D%2522data%253Atext%252Fjavascript%253Bbase64%252C",
                "%2522%253E%253C%252Fscript%253E"
            );
        }
        return (request.wrapPrefix, request.wrapSuffix);
    }

    // Making public as this can be used without scripty html builder
    function buildWrappedScriptsAndGetSize(
        ScriptRequest[] memory requests
    ) public view returns (uint256) {
        if (requests.length == 0) {
            return 0;
        }
        bytes memory wrapPrefix;
        bytes memory wrapSuffix;

        uint256 i;
        uint256 length = requests.length;
        uint256 totalSize;
        unchecked {
            do {
                bytes memory script = _fetchScript(requests[i]);
                requests[i].scriptContent = script;

                (wrapPrefix, wrapSuffix) = _wrapPrefixAndSuffixFor(requests[i]);
                requests[i].wrapPrefix = wrapPrefix;
                requests[i].wrapSuffix = wrapSuffix;

                totalSize += wrapPrefix.length;
                totalSize += script.length;
                totalSize += wrapSuffix.length;
            } while (++i < length);
        }
        return totalSize;
    }

    // Making public as this can be used without scripty html builder
    // this can be also unified with above. shouldIncludeTags: Bool
    function buildInlineScriptsAndGetSize(
        ScriptRequest[] memory requests
    ) public view returns (uint256) {
        if (requests.length == 0) {
            return 0;
        }
        uint256 i;
        uint256 length = requests.length;
        uint256 totalSize;
        unchecked {
            do {
                bytes memory script = _fetchScript(requests[i]);
                requests[i].scriptContent = script;

                totalSize += script.length;
            } while (++i < length);
        }
        return totalSize;
    }

    /**
     * @notice Grabs requested script from storage
     * @param scriptRequest - Name given to the script. Eg: threejs.min.js_r148
     */
    function _fetchScript(
        ScriptRequest memory scriptRequest
    ) internal view returns (bytes memory) {
        if (scriptRequest.scriptContent.length > 0) {
            return scriptRequest.scriptContent;
        }

        return
            IContractScript(scriptRequest.contractAddress).getScript(
                scriptRequest.name,
                scriptRequest.contractData
            );
    }

    /**
     * @notice Append requests to the html buffer for head tags
     * @param htmlFile - bytes buffer
     * @param headRequests - Request being added to buffer
     */
    function _appendHeadRequests(
        bytes memory htmlFile,
        HeadRequest[] memory headRequests
    ) internal pure {
        HeadRequest memory headRequest;
        uint256 i;
        unchecked {
            do {
                headRequest = headRequests[i];
                htmlFile.appendSafe(headRequest.wrapPrefix);
                htmlFile.appendSafe(headRequest.scriptContent);
                htmlFile.appendSafe(headRequest.wrapSuffix);
            } while (++i < headRequests.length);
        }
    }

    function _appendScriptRequests(
        bytes memory htmlFile,
        ScriptRequest[] memory scriptRequests,
        bool includeTags,
        bool encodeScripts
    ) internal pure {
        uint256 i;
        unchecked {
            do {
                _appendScriptRequest(
                    htmlFile,
                    scriptRequests[i],
                    includeTags,
                    encodeScripts
                );
            } while (++i < scriptRequests.length);
        }
    }

    function _appendScriptRequest(
        bytes memory htmlFile,
        ScriptRequest memory scriptRequest,
        bool includeTags,
        bool encodeScripts
    ) internal pure {        
        if (includeTags) {
            htmlFile.appendSafe(scriptRequest.wrapPrefix);
        }
        if (encodeScripts) {
            htmlFile.appendSafeBase64(
                scriptRequest.scriptContent,
                false,
                false
            );
        } else {
            htmlFile.appendSafe(scriptRequest.scriptContent);
        }
        if (includeTags) {
            htmlFile.appendSafe(scriptRequest.wrapSuffix);
        }
    }

    /**
     * @notice Get the total buffer size for the head tags
     * @param headRequests - Request being added to buffer
     * @return size - buffer size for head tags
     */
    function getBufferSizeForHeadTags(
        HeadRequest[] memory headRequests
    ) public pure returns (uint256 size) {
        if (headRequests.length == 0) {
            return 0;
        }
        HeadRequest memory headRequest;
        uint256 i;
        unchecked {
            do {
                headRequest = headRequests[i];
                size += headRequest.scriptContent.length;
                size += headRequest.wrapPrefix.length;
                size += headRequest.wrapSuffix.length;
            } while (++i < headRequests.length);
        }
    }


    // Might be useful for offchain. It just calculates the 
    // buffer size for scripts. If this sripts are not fetched/built
    // then this method will return wrong buffer size. Should we 
    // keep it?
    function getBufferSizeForScriptRequests(
        ScriptRequest[] calldata scriptRequests
    ) public pure returns (uint256 size) {
        if (scriptRequests.length == 0) {
            return 0;
        }
        ScriptRequest memory scriptRequest;
        uint256 i;
        unchecked {
            do {
                scriptRequest = scriptRequests[i];
                size += scriptRequest.scriptContent.length;
                size += scriptRequest.wrapPrefix.length;
                size += scriptRequest.wrapSuffix.length;
            } while (++i < scriptRequests.length);
        }
    }


    /**
     * @notice Calculate the buffer size post base64 encoding
     * @param value - Starting buffer size
     * @return Final buffer size as uint256
     */
    function _sizeForBase64Encoding(
        uint256 value
    ) internal pure returns (uint256) {
        unchecked {
            return 4 * ((value + 2) / 3);
        }
    }
}
