import { ethers } from 'ethers';
import { useEffect, useState } from 'react';
import axios from 'axios';
import Web3Modal from 'web3modal';

import { nftmarketaddress, nftaddress } from '../config';

import Market from '../artifacts/contracts/Market.sol/NFTMarket.json';
import NFT from '../artifacts/contracts/NFT.sol/NFT.json';
import { useRouter } from 'next/router';
import { TransactionDescription } from 'ethers/lib/utils';

export default function MyAssets() {
  const [nfts, setNfts] = useState([]);
  const [loadingState, setLoadingState] = useState('not-loaded');
  const router = useRouter();
  useEffect(() => {
    loadNFTs();
  }, []);
  async function loadNFTs() {
    const web3Modal = new Web3Modal({
      network: 'mainnet',
      cacheProvider: true,
    });
    const connection = await web3Modal.connect();
    console.log('Connection', connection);
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const marketContract = new ethers.Contract(
      nftmarketaddress,
      Market.abi,
      signer
    );

    const tokenContract = new ethers.Contract(nftaddress, NFT.abi, provider);
    const data = await marketContract.fetchMyNFTs();

    const items = await Promise.all(
      data.map(async (i) => {
        const tokenUri = await tokenContract.tokenURI(i.tokenId);
        const meta = await axios.get(tokenUri);
        let price = ethers.utils.formatUnits(i.price.toString(), 'ether');
        let item = {
          price,
          tokenId: i.tokenId.toNumber(),
          seller: i.seller,
          owner: i.owner,
          image: meta.data.image,
          itemId: i.itemId.toNumber(),
        };
        return item;
      })
    );
    setNfts(items);
    setLoadingState('loaded');
  }

  async function putOnSale(tokenId, price, itemId) {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    let tokenContract = new ethers.Contract(nftaddress, NFT.abi, signer);
    let marketContract = new ethers.Contract(
      nftmarketaddress,
      Market.abi,
      signer
    );
    let listingPrice = await marketContract.getListingPrice();
    listingPrice = listingPrice.toString();
    console.log('Listing Price in My assets', listingPrice);
    const itemPrice = ethers.utils.parseUnits(price, 'ether');
    console.log('Price is ', itemPrice);
    console.log('Token Id is ', tokenId);

    console.log('Item id', itemId);
    let approvalTransaction = await tokenContract.setApprovalfunc();
    await approvalTransaction.wait();
    console.log('Approval set done');
    let transaction = await marketContract.resellItem(
      nftaddress,
      tokenId,
      itemId,
      itemPrice,
      {
        value: listingPrice,
      }
    );
    await transaction.wait();
    console.log('transaction for changing status done', transaction);
    router.push('/');
  }
  if (loadingState === 'loaded' && !nfts.length)
    return <h1 className="py-10 px-20 text-3xl">No assets owned</h1>;
  return (
    <div className="flex justify-center">
      <div className="p-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
          {nfts.map((nft, i) => (
            <div key={i} className="border shadow rounded-xl overflow-hidden">
              <img src={nft.image} className="rounded"/>
              <div className="p-4 bg-black">
                <p className="text-2xl font-bold text-white">
                  Price - {nft.price} Eth
                </p>
              </div>
              <button
                onClick={async () => {
                  await putOnSale(nft.tokenId, nft.price, nft.itemId);
                }}
              >
                Put on Sale
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
