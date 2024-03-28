import {ethers} from 'ethers';
import {TypedDataDomain} from "ethers/src.ts/hash/typed-data";

const odosLimitOrderRouterAbi = [
  {
    "type": "function",
    "name": "getLimitOrderHash",
    "inputs": [
      {
        "name": "order",
        "type": "tuple",
        "internalType": "struct OdosLimitOrderRouter.LimitOrder",
        "components": [
          {
            "name": "input",
            "type": "tuple",
            "internalType": "struct OdosLimitOrderRouter.TokenInfo",
            "components": [
              {
                "name": "tokenAddress",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "tokenAmount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "output",
            "type": "tuple",
            "internalType": "struct OdosLimitOrderRouter.TokenInfo",
            "components": [
              {
                "name": "tokenAddress",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "tokenAmount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "expiry",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "salt",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "referralCode",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "partiallyFillable",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "hash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getMultiLimitOrderHash",
    "inputs": [
      {
        "name": "order",
        "type": "tuple",
        "internalType": "struct OdosLimitOrderRouter.MultiLimitOrder",
        "components": [
          {
            "name": "inputs",
            "type": "tuple[]",
            "internalType": "struct OdosLimitOrderRouter.TokenInfo[]",
            "components": [
              {
                "name": "tokenAddress",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "tokenAmount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "outputs",
            "type": "tuple[]",
            "internalType": "struct OdosLimitOrderRouter.TokenInfo[]",
            "components": [
              {
                "name": "tokenAddress",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "tokenAmount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "expiry",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "salt",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "referralCode",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "partiallyFillable",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "hash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  }
]

const SingleLimtOrderTypes = {
  TokenInfo: [
    {name: 'tokenAddress', type: 'address'},
    {name: 'tokenAmount', type: 'uint256'},
  ],
  LimitOrder: [
    {name: 'input', type: 'TokenInfo'},
    {name: 'output', type: 'TokenInfo'},
    {name: 'expiry', type: 'uint256'},
    {name: 'salt', type: 'uint256'},
    {name: 'referralCode', type: 'uint32'},
    {name: 'partiallyFillable', type: 'bool'},
  ],
};

const MultiLimtOrderTypes = {
  TokenInfo: [
    {name: 'tokenAddress', type: 'address'},
    {name: 'tokenAmount', type: 'uint256'},
  ],
  MultiLimitOrder: [
    {name: 'inputs', type: 'TokenInfo[]'},
    {name: 'outputs', type: 'TokenInfo[]'},
    {name: 'expiry', type: 'uint256'},
    {name: 'salt', type: 'uint256'},
    {name: 'referralCode', type: 'uint32'},
    {name: 'partiallyFillable', type: 'bool'},
  ],
};

const singleLimitOrderValue = {
  input: {
    tokenAddress: "0xa0Cb889707d426A7A386870A03bc70d1b0697598",
    tokenAmount: "2001000000000000000000",
  },
  output: {
    tokenAddress: "0xc7183455a4C133Ae270771860664b6B7ec320bB1",
    tokenAmount: "2001000000",
  },
  expiry: 1 + 86400,
  salt: 1,
  referralCode: 0,
  partiallyFillable: false,
};

const multiLimitOrderValue = {
  inputs: [
    {tokenAddress: '0xa0Cb889707d426A7A386870A03bc70d1b0697598', tokenAmount: '1999000000000000000000'},
    {tokenAddress: '0x1d1499e622D69689cdf9004d05Ec547d650Ff211', tokenAmount: '2001000000000000000000'},
  ],
  outputs: [
    {tokenAddress: '0xc7183455a4C133Ae270771860664b6B7ec320bB1', tokenAmount: '2002000000'},
    {tokenAddress: '0xA4AD4f68d0b91CFD19687c881e50f3A00242828c', tokenAmount: '1998000000000000000000'},
  ],
  expiry: 1 + 86400,
  salt: 1,
  referralCode: 0,
  partiallyFillable: false,
};

const providerUrl = "http://127.0.0.1:8545";

// Default anvil address for the first deployment
const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const provider = new ethers.JsonRpcProvider(providerUrl);
const contract = new ethers.Contract(contractAddress, odosLimitOrderRouterAbi, provider);

let domain: TypedDataDomain;

beforeAll(async () => {
  const network = await provider.getNetwork();
  domain = {
    name: 'OdosLimitOrderRouter',
    version: '1',
    chainId: network.chainId,
    verifyingContract: contractAddress
  };
});


test('LimitOrder hash should be equal', async () => {
  const hash1 = await contract.getLimitOrderHash(singleLimitOrderValue);
  const hash2 = ethers.TypedDataEncoder.hash(domain, SingleLimtOrderTypes, singleLimitOrderValue);

  expect(hash1).toBe(hash2);
});

test('MultiLimitOrder hash should be equal', async () => {
  const hash3 = await contract.getMultiLimitOrderHash(multiLimitOrderValue);
  const hash4 = ethers.TypedDataEncoder.hash(domain, MultiLimtOrderTypes, multiLimitOrderValue);

  expect(hash3).toBe(hash4);
});
