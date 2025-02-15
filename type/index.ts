import { CoinMetadata } from "@mysten/sui/client";

export type Board = {
  id: { id: string };
  creator: string;
  name: string;
  description: string;
  img_url: string;
  tasks: {
    fields: {
      id: { id: string };
      size: string;
    };
  };
  total_pledged: bigint;
  members: string[];
  created_at: number;
  closed: boolean;
};

export interface Task {
  id: { id: string };
  value: {
    fields: {
      name: string;
      creator: string;
      description: string;
      deadline: number;
      max_completions: number;
      reviewers: string[];
      submissions: {
        fields: {
          id: { id: string };
          size: string;
        };
      };
      completed: boolean;
      rewardAmount: string;
      created_at: number;
      cancelled: boolean;
      config: string;
      allow_self_check: boolean;
    };
  };
  task_address: string;
  object_id: string;
}

export type Profile = {
  id: { id: string };
  value: {
    fields: {
      username: string; // 用户名
      email: string; // 邮箱
      role: string; // 角色
      bio: string; // 个人简介
      user_address: string; // 用户地址
      created_boards: string[]; // 创建的赏金板列表
      join_boards: string[]; // 加入的赏金板列表
      created_at: number; // 创建时间
    };
  };
};

export type Submission = {
  id: { id: string };
  value: {
    fields: {
      id: { id: string };
      task_id: string;
      submitter: string;
      proof: string;
      status: {
        variant: string;
      };
      submitted_at: string;
      review_comment: string;
    };
  };
};

export type SuiObject = {
  id: string;
  type: string;
  coinMetadata?: CoinMetadata;
  balance?: number;
};

export interface State {
  boards: EventBoardCreated[];
}

export type EventBoardCreated = {
  board_id: string;
  name: string;
  description: string;
  reward_token_type: { name: string };
  reward_token_amount: bigint;
  created_at: string;
};
