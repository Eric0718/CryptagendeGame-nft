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
        const amount = "100"

        await crypta.mint(amount)
        const expectAmount = await crypta.totalSupply()

        assert.equal(expectAmount.toString(),amount)

        const uri = await crypta.tokenURI(amount)
    })

});


