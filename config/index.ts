import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { createNetworkConfig } from "@mysten/dapp-kit";

const { networkConfig, useNetworkVariable, useNetworkVariables } =
  createNetworkConfig({
    devnet: {
      url: getFullnodeUrl("devnet"),
      packageID:
        "0xd934bfd781bcef44adedf11a8b507e63db26b652957058fb4a91fe3c2dbc37d2",
      userProfilePortal:
        "0xf0f0bee73be0a6b56eeb1a46b125d537025a751b7976152a74c41cbd261d5a7b",
    },
    testnet: {
      url: getFullnodeUrl("testnet"),
      packageID:
        "0xd3a2cb3f1df0cd8ce4570d1fb122f10ce68434a95304830dca86d0711f2c597a",
      userProfilePortal:
        "0x5f11507ec60701ca8f704fd0f54dbd5e4301cb1be735c4cb025977fab50dae93",
    },
    mainnet: {
      url: getFullnodeUrl("mainnet"),
    },
  });

const suiClient = new SuiClient({
  url: networkConfig.devnet.url,
});

const suiGraphQLClient = new SuiGraphQLClient({
  url: `https://sui-devnet.mystenlabs.com/graphql`,
});

export { useNetworkVariable, useNetworkVariables, networkConfig, suiClient, suiGraphQLClient };
