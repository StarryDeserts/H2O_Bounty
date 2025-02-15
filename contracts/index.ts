import { networkConfig, suiClient, suiGraphQLClient } from "@/config";
import { Transaction } from "@mysten/sui/transactions";
import { Board, State, SuiObject, EventBoardCreated, Profile, Task } from "../type";
import { isValidSuiAddress } from "@mysten/sui/utils";
import { graphql } from "@mysten/sui/graphql/schemas/latest";
import {
  SuiObjectResponse,
  SuiParsedData,
  SuiObjectData,
} from "@mysten/sui/client";
import {
  BountyBoardModule,
  UserProfilePortalModule,
  Clock,
  CoinType,
} from "@/constant";

/*---query event---*/

// 查询所有创建 Board 的事件并将其渲染到首页
export const queryCreateBoardEvent: () => Promise<State> = async () => {
  const events = await suiClient.queryEvents({
    query: {
      MoveEventType: `${networkConfig.devnet.packageID}::${BountyBoardModule.MODULE_NAME}::${BountyBoardModule.EVENTS.BOARD_CREATED}${BountyBoardModule.EVENTS.EVENT_TYPE.SUI}`,
    },
  });
  const state: State = {
    boards: [],
  };
  events.data.forEach((event) => {
    if (event.parsedJson) {
      const board = event.parsedJson as EventBoardCreated;
      if (board && typeof board === "object") {
        state.boards.push({
          ...board,
        });
      }
    }
  });
  console.log(state);
  return state;
};

// 获取链上 Board 的详细信息
export const queryBoard = async (address: string) => {
  if (!isValidSuiAddress(address)) {
    throw new Error("Invalid board address");
  }
  const boardContent = await suiClient.getObject({
    id: address,
    options: {
      showContent: true,
    },
  });

  if (!boardContent.data?.content) {
    throw new Error("Board content not found");
  }

  const parsedBoard = boardContent.data.content as SuiParsedData;
  if (!("fields" in parsedBoard)) {
    throw new Error("Invalid board data structure");
  }

  const board = parsedBoard.fields as unknown as Board;
  if (!board) {
    throw new Error("Invalid board data structure");
  }

  return board;
};

// 获取链上 Profile 的详细信息
export const queryProfile = async (address: string) => {
  if (!isValidSuiAddress(address)) {
    throw new Error("Invalid board address");
  }
  const profileContent = await suiClient.getObject({
    id: "0x73333045888b05341ae27cef3656d733a6c136467362b19c2dae0cbb87275eec",
    options: {
      showContent: true,
    },
  });

  if (!profileContent.data?.content) {
    throw new Error("Profile content not found");
  }

  const parseProfile = profileContent.data.content as SuiParsedData;
  if (!("fields" in parseProfile)) {
    throw new Error("Invalid profile data structure");
  }
  const profileData = parseProfile.fields as Profile;
  if (!profileData) {
    throw new Error("Invalid profile data structure");
  }
  return profileData;
};

export const queryObjects = async (address: string) => {
  if (!isValidSuiAddress(address)) {
    throw new Error("Invalid board address");
  }

  try {
    let cursor: string | null | undefined = null;
    let hasNextPage = true;
    let objects: SuiObjectResponse[] = [];
    let suiObjects: SuiObject[] = [];

    while (hasNextPage) {
      const rawObjects = await suiClient.getOwnedObjects({
        owner: address,
        options: {
          showContent: true,
          showType: true, // Add type info for better filtering
        },
        cursor,
        // Add limit to prevent too many requests
        limit: 50,
      });

      if (!rawObjects?.data) {
        break;
      }

      hasNextPage = rawObjects.hasNextPage;
      cursor = rawObjects.nextCursor;
      objects.push(...rawObjects.data);
    }
    objects.map((object) => {
      const objectData = object.data as SuiObjectData;
      const suiObject: SuiObject = {
        id: objectData.objectId,
        type: objectData.type || "",
      };
      if (objectData.content) {
        const parsedData = objectData.content as SuiParsedData;
        if (parsedData.dataType === "moveObject") {
          const balance = parsedData.fields as unknown as { balance: string };
          suiObject.balance = parseInt(balance.balance);
        }
      }
      suiObjects.push(suiObject);
    });

    return suiObjects;
  } catch (error) {
    console.error("Failed to query objects:", error);
    throw new Error("Failed to fetch owned objects");
  }
};

export const queryTaskData = async (task_id: string) => {
  const taskData = await suiClient.getDynamicFields({
    parentId: task_id,
  });
  return taskData;
};

export const queryTask = async (task_object_id: string) => {
  if (!isValidSuiAddress(task_object_id)) {
    throw new Error("Invalid task address");
  }
  const taskContent = await suiClient.getObject({
    id: task_object_id,
    options: {
      showContent: true,
    },
  });

  if (!taskContent.data?.content) {
    throw new Error("Task content not found");
  }

  const parsedTask = taskContent.data.content as SuiParsedData;
  if (!("fields" in parsedTask)) {
    throw new Error("Invalid task data structure");
  }

  const task = parsedTask.fields as unknown as Task;
  if (!task) {
    throw new Error("Invalid task data structure");
  }
  return task;
}

export const querySubmissionData = async (sub_id: string) => {
  const taskData = await suiClient.getDynamicFields({
    parentId: sub_id,
  });
  return taskData;
};

export const querySubmission = async (sub_object_id: string) => {
  if (!isValidSuiAddress(sub_object_id)) {
    throw new Error("Invalid sub address");
  }
  const subContent = await suiClient.getObject({
    id: sub_object_id,
    options: {
      showContent: true,
    },
  });

  if (!subContent.data?.content) {
    throw new Error("Sub content not found");
  }

  const parsedSub = subContent.data.content as SuiParsedData;
  if (!("fields" in parsedSub)) {
    throw new Error("Invalid sub data structure");
  }

  const sub = parsedSub.fields as unknown as Task;
  if (!sub) {
    throw new Error("Invalid sub data structure");
  }
  return sub;
}

const queryTaskDataContext = graphql(`
  query queryTaskDataContext($address: SuiAddress!) {
    object(address: $address) {
      dynamicFields {
        nodes {
          name {
            json
          }
          value {
            ... on MoveValue {
              json
            }
          }
        }
      }
    }
  }
`);

export const queryTaskDataByGraphQL = async (task_id: string) => {
  const result = await suiGraphQLClient.query({
    query: queryTaskDataContext,
    variables: {
      address: task_id,
    },
  });
  const taskData =
    result.data?.object?.dynamicFields?.nodes?.map((node) => {
      const nameJson = node.name as { json: { name: string } };
      const valueJson = node.value as { json: { value: string } };
      return {
        name: nameJson.json.name,
        value: valueJson.json.value,
      };
    }) ?? [];
  console.log(taskData);
  return taskData;
};

/*---function call---*/

// 创建 UserProfile
export const createUserProfile = async (
  username: string,
  email: string,
  role: string,
  bio: string
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: UserProfilePortalModule.MODULE_NAME,
    function: UserProfilePortalModule.FUNCTIONS.CREATE_USER_PROFILE,
    arguments: [
      tx.object(networkConfig.devnet.userProfilePortal),
      tx.pure.string(username),
      tx.pure.string(email),
      tx.pure.string(role),
      tx.pure.string(bio),
      tx.object(Clock),
    ],
  });
  return tx;
};

// 创建新的 Board
export const createBoard = async (
  board_name: string,
  description: string,
  image_url: string,
  amount: bigint
) => {
  const tx = new Transaction();
  const [sui] = tx.splitCoins(tx.gas, [amount]);
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.CREATE_BOARD,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(networkConfig.devnet.userProfilePortal),
      tx.pure.string(board_name),
      tx.pure.string(description),
      tx.pure.string(image_url),
      sui,
      tx.object(Clock),
    ],
  });
  return tx;
};

// 加入 Board
export const joinBoard = async (board_id: string) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.JOIN_BOARD,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(networkConfig.devnet.userProfilePortal),
      tx.object(board_id),
      tx.object(Clock),
    ],
  });
  return tx;
};

// 关闭 Board 并拿回剩余的奖励
export const withdrawRewardTokenAndCloseBoard = async (
  board_id: string
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.WITHDRAW_REWARD_TOKEN_AND_CLOSE_BOARD,
    typeArguments: [CoinType.SUI],
    arguments: [tx.object(board_id), tx.object(Clock)],
  });
  return tx;
};

// 创建新的 Task
export const createTask = async (
  board_id: string,
  task_name: string,
  description: string,
  deadline: bigint,
  max_completions: number,
  reward: bigint,
  allow_self_check: boolean,
  config: string
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.CREATE_TASK,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(board_id),
      tx.pure.string(task_name),
      tx.pure.string(description),
      tx.pure.u64(deadline),
      tx.pure.u64(max_completions),
      tx.pure.u64(reward),
      tx.pure.bool(allow_self_check),
      tx.pure.string(config),
      tx.object(Clock),
    ],
  });
  return tx;
};

// 提交任务证明
export const submitTask = async (
  board_id: string,
  task_id: string,
  proof: string
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.SUBMIT_TASK_PROOF,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(board_id),
      tx.pure.address(task_id),
      tx.pure.string(proof),
      tx.object(Clock),
    ],
  });
  return tx;
};

// 审核通过并发放奖励
export const reviewSubmission = async (
  board_id: string,
  task_id: string,
  submitter: string,
  review_comment: string,
  status: number
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.REVIEW_SUBMISSION,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(board_id),
      tx.pure.address(task_id),
      tx.pure.address(submitter),
      tx.pure.string(review_comment),
      tx.pure.u64(status),
      tx.object(Clock),
    ],
  });
  return tx;
};

// board 的创建者为自己的 board 中的 Task 加入审核者
export const addReviewer = async (
  board_id: string,
  task_id: string,
  reviewer: string[]
) => {
  const tx = new Transaction();
  tx.moveCall({
    package: networkConfig.devnet.packageID,
    module: BountyBoardModule.MODULE_NAME,
    function: BountyBoardModule.FUNCTIONS.ADD_REVIEWER,
    typeArguments: [CoinType.SUI],
    arguments: [
      tx.object(board_id),
      tx.pure.address(task_id),
      tx.pure.vector("address", reviewer),
    ],
  });
  return tx;
};
