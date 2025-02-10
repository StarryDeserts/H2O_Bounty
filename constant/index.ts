export const BountyBoardModule = {
  MODULE_NAME: "bountyboard",
  FUNCTIONS: {
    CREATE_BOARD: "create_board",
    UPDATE_BOARD_BASIC_INFO: "update_board_basic_info",
    ADD_REWARD_TOKEN: "add_reward_token",
    JOIN_BOARD: "join_board",
    WITHDRAW_REWARD_TOKEN_AND_CLOSE_BOARD:
      "withdraw_reward_token_and_close_board",
    CREATE_TASK: "create_task",
    UPDATE_TASK: "update_task",
    CANCEL_TASK: "cancel_task",
    SUBMIT_TASK_PROOF: "submit_task_proof",
    REVIEW_SUBMISSION: "review_submission",
    RESUBMIT_TASK_PROOF: "resubmit_task_proof",
    ADD_REVIEWER: "add_reviewer",
  },
  EVENTS: {
    BOARD_CREATED: "BoardCreatedEvent",
    BOARD_UPDATED: "BoardUpdatedBasicInfoEvent",
    EVENT_TYPE : {
      SUI: "<0x2::sui::SUI>"
    }
  }
} as const;

export const UserProfilePortalModule = {
  MODULE_NAME: "UserProfilePortal",
  FUNCTIONS: {
    CREATE_USER_PROFILE: "create_user_profile",
    UPDATE_USER_PROFILE: "update_user_profile",
    GET_USER_PROFILE: "get_user_profile",
    GET_ALL_USER_ADDRESSES: "get_all_user_addresses",
    GET_USER_CREATED_BOARDS: "get_user_created_boards",
    GET_USER_JOINED_BOARDS: "get_user_joined_boards",
    GET_ALL_USER_CREATED_BOARDS: "get_all_user_created_boards",
  },
  STRUCT: {
    PROFILE: "UserProfile",
  },
} as const;

// 资产类型
export const CoinType = {
  SUI: "0x2::sui::SUI",
  USDC: {
    TESTNET:
      "0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC",
    MAINNET:
      "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
  },
} as const;

// 时钟对象
export const Clock = "0x6";

// 状态常量
export const SUBMISSION_STATUS = {
  REJECTED: 0,
  APPROVED: 1,
} as const;
