const {ethers} = require("hardhat")
const {expect,assert} = require("chai")

describe("CryptagendeGame",function(){
    let cryptaFactory,crypta
    const { _, log } = deployments
    beforeEach(async function(){
        cryptaFactory = await ethers.getContractFactory("CryptagendeGame")
        crypta = await cryptaFactory.deploy(
        "qweasd",
        "qwe",
        "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
        "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc")
    });

    it("testName",async function(){
        expect(await crypta.name()).to.equal("qweasd");
    });

    it("testMint",async function(){
        const amount = "50"
        value = "5000000000000000000"
        await crypta.mint(amount,{ value: value })
        const expectAmount = await crypta.totalSupply()

        assert.equal(expectAmount.toString(),amount)

        const uri = await crypta.tokenURI(amount)
        console.log(
            "tokenId: %s,URI: %s,totalSupply: %d",
            amount,
            uri,
            expectAmount
        )
    })
});


