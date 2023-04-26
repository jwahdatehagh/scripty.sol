// const { expect } = require("chai");
// const utilities = require("../utilities/utilities")

// const recordMode = false;
// const expectedResultsPath = __dirname + "/expectedResults/";

// const writeHTMLResult = (name, result) => {
//     const fileName = name.replace(/\s/g, '');
//     utilities.writeFile(expectedResultsPath + fileName + ".html", result)
// }

// const readExpectedHTMLResult = (name) => {
//     const fileName = name.replace(/\s/g, '');
//     const data = utilities.readFile(expectedResultsPath + fileName + ".html")
//     return data;
// }

// const expectHTML = (name, actual) => {
//     if (recordMode) {
//         writeHTMLResult(name, actual)
//         return
//     }
//     const expected = readExpectedHTMLResult(name)
//     expect(actual).to.equal(expected)
// }

// describe("ScriptyWrappedHTML Tests", function () {
//     const controllerScript = "controllerScript"

//     async function deploy() {
//         const contentStore = await (await ethers.getContractFactory("ContentStore")).deploy()
//         await contentStore.deployed()

//         const scriptyStorageContract = await (await ethers.getContractFactory("ScriptyStorage")).deploy(
//             contentStore.address
//         )
//         await scriptyStorageContract.deployed()

//         const scriptyWrappedHTMLContract = await (await ethers.getContractFactory("ScriptyWrappedHTML")).deploy()
//         await scriptyWrappedHTMLContract.deployed()

//         return { scriptyStorageContract, scriptyWrappedHTMLContract }
//     }

//     function createControllerScriptRequestWrapped(wrapType) {
//         if (wrapType == 4) {
//             return ["", utilities.emptyAddress, 0, wrapType, utilities.stringToBytes("wrapPrefix"), utilities.stringToBytes("wrapSuffix"), utilities.stringToBytes(controllerScript)]
//         }
//         return ["", utilities.emptyAddress, 0, wrapType, utilities.emptyBytes(), utilities.emptyBytes(), utilities.stringToBytes(controllerScript)]
//     }

//     async function addHeadTag() {
//         return [
//             utilities.stringToBytes("<title>"),
//             utilities.stringToBytes("</title>"),
//             utilities.stringToBytes("Hello World")
//         ]
//     }

//     async function addWrappedScripts(
//         scriptyStorageContract,
//         wrapType
//     ) {
//         const script = "wrappedScript"
//         let wrapPrefix = utilities.emptyBytes()
//         let wrapSuffix = utilities.emptyBytes()
//         let scriptContent = utilities.emptyBytes()

//         if (wrapType == 4) {
//             wrapPrefix = utilities.stringToBytes("wrapPrefix")
//             wrapSuffix = utilities.stringToBytes("wrapSuffix")
//         }

//         let scriptRequests = []

//         for (let i = 0; i < 2; i++) {
//             let scriptName = "script" + i
//             await scriptyStorageContract.createScript(scriptName, utilities.stringToBytes("details"))
//             await scriptyStorageContract.addChunkToScript(scriptName, utilities.stringToBytes(script + i))
//             scriptRequests.push([scriptName, scriptyStorageContract.address, 0, wrapType, wrapPrefix, wrapSuffix, scriptContent])
//         }

//         return { scriptRequests }
//     }

//     async function wrappedCallWithSizeCheck(title, contract, headTags, requests, isEncoded = false) {
//         const scriptSize = await contract.getBufferSizeForHTMLWrapped(headTags, requests)
//         const invalidSize = scriptSize.sub(ethers.BigNumber.from(1))

//         const htmlRaw = await contract.getHTMLWrapped(headTags, requests, scriptSize)
//         const htmlRawString = utilities.bytesToString(htmlRaw)

//         if (isEncoded) {
//             const htmlEncoded = await contract.getEncodedHTMLWrapped(headTags, requests, scriptSize)
//             const htmlEncodedString = utilities.bytesToString(htmlEncoded)

//             expect(htmlRawString).to.be.equal(utilities.parseBase64DataURI(htmlEncodedString))
//             expectHTML(title, htmlEncodedString);

//             await expect(contract.getEncodedHTMLWrapped(headTags, requests, invalidSize))
//                 .to.be.revertedWith('DynamicBuffer: Appending out of bounds.');
//         } else {
//             expectHTML(title, htmlRawString);

//             await expect(contract.getHTMLWrapped(headTags, requests, invalidSize))
//                 .to.be.revertedWith('DynamicBuffer: Appending out of bounds.');
//         }
//     }

//     describe("Store Script and get raw HTML", async function () {

//         async function wrapTypeTest(title, wrapType) {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             const { scriptRequests } = await addWrappedScripts(scriptyStorageContract, wrapType)

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(title, scriptyWrappedHTMLContract, headTags, scriptRequests);
//         }

//         it("Store Script and get HTML - Wrapped - Wrap Type 0", async function () {
//             await wrapTypeTest(this.test.fullTitle(),0)
//         });

//         it("Store Script and get HTML - Wrapped - Wrap Type 1", async function () {
//             await wrapTypeTest(this.test.fullTitle(),1)
//         });

//         it("Store Script and get HTML - Wrapped - Wrap Type 2", async function () {
//             await wrapTypeTest(this.test.fullTitle(),2)
//         });

//         it("Store Script and get HTML - Wrapped - Wrap Type 3", async function () {
//             await wrapTypeTest(this.test.fullTitle(),3)
//         });

//         it("Store Script and get HTML - Wrapped - Wrap Type 4", async function () {
//             await wrapTypeTest(this.test.fullTitle(),4)
//         });
//     })

//     describe("Store Script and get raw HTML with controller script", async function () {

//         async function controllerScriptTest(title, wrapType) {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.push(
//                 createControllerScriptRequestWrapped(wrapType)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(title, scriptyWrappedHTMLContract, headTags, scriptRequests, false);
//         }

//         it("Store Script and get HTML - Wrapped - Controller Script (wrapType 0)", async function () {
//             await controllerScriptTest(this.test.fullTitle(),0)
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script (wrapType 1)", async function () {
//             await controllerScriptTest(this.test.fullTitle(),1)
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script (wrapType 2)", async function () {
//             await controllerScriptTest(this.test.fullTitle(),2)
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script (wrapType 3)", async function () {
//             await controllerScriptTest(this.test.fullTitle(),3)
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script (wrapType 4)", async function () {
//             await controllerScriptTest(this.test.fullTitle(),4)
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script at beginning", async function () {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.splice(0, 0,
//                 createControllerScriptRequestWrapped(0)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(this.test.fullTitle(), scriptyWrappedHTMLContract, headTags, scriptRequests);
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script in middle", async function () {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.splice(1, 0,
//                 createControllerScriptRequestWrapped(0)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(this.test.fullTitle(), scriptyWrappedHTMLContract, headTags, scriptRequests);
//         });

//         it("Store Script and get HTML - Wrapped - Controller Script at the end", async function () {
//             await controllerScriptTest(this.test.fullTitle(),0)
//         });
//     })

//     describe("Store Script and get encoded HTML", async function () {

//         async function wrapTypeWithEncodingTest(title, wrapType) {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             const { scriptRequests } = await addWrappedScripts(scriptyStorageContract, wrapType)

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(title, scriptyWrappedHTMLContract, headTags, scriptRequests, true);
//         }

//         it("Store Script and get Encoded HTML - Wrapped - Wrap Type 0", async function () {
//             await wrapTypeWithEncodingTest(this.test.fullTitle(),0)
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Wrap Type 1", async function () {
//             await wrapTypeWithEncodingTest(this.test.fullTitle(),1)
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Wrap Type 2", async function () {
//             await wrapTypeWithEncodingTest(this.test.fullTitle(),2)
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Wrap Type 3", async function () {
//             await wrapTypeWithEncodingTest(this.test.fullTitle(),3)
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Wrap Type 4", async function () {
//             await wrapTypeWithEncodingTest(this.test.fullTitle(),4)
//         });
//     })

//     describe("Store Script and get Encoded HTML with controller script", async function () {

//         async function controllerScriptWithEncodingTest(title, wrapType) {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.push(
//                 createControllerScriptRequestWrapped(wrapType)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(title, scriptyWrappedHTMLContract, headTags, scriptRequests, true);
//         }

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script (wrapType 0)", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),0);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script (wrapType 1)", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),1);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script (wrapType 2)", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),2);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script (wrapType 3)", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),3);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script (wrapType 4)", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),4);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script at beginning", async function () {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.splice(0, 0,
//                 createControllerScriptRequestWrapped(0)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(this.test.fullTitle(), scriptyWrappedHTMLContract, headTags, scriptRequests, true);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script in middle", async function () {
//             const { scriptyStorageContract, scriptyWrappedHTMLContract } = await deploy()
//             let { scriptRequests } = await addWrappedScripts(scriptyStorageContract, 0)

//             scriptRequests.splice(1, 0,
//                 createControllerScriptRequestWrapped(0)
//             );

//             const headTags = [await addHeadTag()];
//             await wrappedCallWithSizeCheck(this.test.fullTitle(), scriptyWrappedHTMLContract, headTags, scriptRequests, true);
//         });

//         it("Store Script and get Encoded HTML - Wrapped - Controller Script at the end", async function () {
//             await controllerScriptWithEncodingTest(this.test.fullTitle(),0);
//         });
//     })
// });
