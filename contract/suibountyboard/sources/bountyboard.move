module suibountyboard::bountyboard;

use std::option::destroy_some;
use std::string::{Self, String};
use sui::clock::{Self, Clock};
use std::type_name::{Self, TypeName};
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::table::{Self, Table};
use sui::event;

use suibountyboard::UserProfilePortal::{UserProfilePortal, update_user_profile_on_board_created, update_user_profile_on_board_joined};


// 定义提交的状态常量
const REJECTED: u64 = 0;
const APPROVED: u64 = 1;

// 错误码定义
const ERR_BOARD_IS_CLOSE: u64 = 1; // 板块已关闭
const ERR_BOARD_NO_PERMISSION: u64 = 2; // 没有当前 Board 的权限
const ERR_MEMBER_EXIST: u64 = 3;// 成员已存在
const ERR_TASK_IS_COMPLETED: u64 = 4; // 任务已完成
const ERR_TASK_IS_CANCELLED: u64 = 5; // 任务已取消
const ERR_DEADLINE_PASSED: u64 = 6; // 截止日期已过
const ERR_MEMBER_NOT_EXIST: u64 = 7; // 成员不存在于当前 Board 中
const ERR_SUBMISSION_EXIST: u64 = 8; // 任务已提交
const ERR_SUBMISSION_NOT_REJECT: u64 = 9; // 此提交的状态不为拒绝
const ERR_REWARD_AMOUNT_NOT_ENOUGH: u64 = 10; // 奖励金额不足
const ERR_MAX_COMPLETIONS_REACHED: u64 = 11; // 最大完成次数已达到
const ERR_REWARD_OVERFLOW_POOL: u64 = 12; // 奖励金额超过奖池
const ERR_REVIEWER_EXIST: u64 = 13; // 审核者已存在于当前 Task 中

// BountyBoard 一次性见证
public struct BOUNTYBOARD has drop {}

// BountyBoard 的管理员权限结构
// TODO: 是否真的需要项目方权限（存疑）
public struct ManagerCap has key, store { id: UID }

// Board 的创建者权限结构
public struct CreatorCap has key, store {
    id: UID,
    board_id: ID,
}

// Task的结构
public struct Task has key, store {
    id: UID, // 任务ID
    name: String, // 任务名称
    creator: address, // 任务创建者
    description: String, // 任务描述
    deadline: u64, // 任务截止日期
    maxCompletions: u64, // 最大完成次数
    numCompletions: u64, // 当前完成次数
    reviewers: vector<address>, // 任务审核者列表
    submissions: Table<address, Submission>, // 任务提交列表
    completed: bool, // 任务是否已完成
    rewardAmount: u64, // 任务奖励金额
    created_at: u64, // 任务创建时间
    cancelled: bool, // 任务是否已取消
    config: String, // 任务配置
    allowSelfCheck: bool, // 是否允许自检
}

// 板块结构
public struct Board<phantom T> has key, store {
    id: UID, // 板块ID
    creator: address, // 板块创建者
    name: String, // 板块名称
    description: String, // 板块描述
    img_url: String, // 板块图片
    tasks: Table<address, Task>, // 板块任务列表
    reward_token: Balance<T>, // 板块奖励代币
    total_pledged: u64, // 板块当前奖池总金额
    members: vector<address>, // 板块成员列表
    created_at: u64, // 板块创建时间
    closed: bool, // 板块是否已关闭
}

// 初始化
fun init(otw: BOUNTYBOARD, ctx:&mut TxContext) {
    // 发布者地址
    let publisher_address = ctx.sender();
    // 发布者声明，一次性见证
    let publisher = sui::package::claim(otw, ctx);
    // 创建 BountyBoard 的管理员权限
    let manager_cap = ManagerCap { id: object::new(ctx) };

    // 将发布的一次性见证转移发布者
    transfer::public_transfer(publisher, publisher_address);
    // 授予发布者管理员权限
    transfer::public_transfer(manager_cap, publisher_address);
}

/*------Board 模块------*/

// 创建 Board
public entry fun create_board<T>(
    portal: &mut UserProfilePortal,
    board_name: String, // 板块名称
    board_description: String, // 板块描述
    img_url: String, // 板块图片
    coinType: Coin<T>, // 传入的奖励代币类型
    clock: &Clock,
    ctx: &mut TxContext
) {
    //1. 创建板块
    let amount = coinType.value();
    let mut board = Board {
        id: object::new(ctx),
        creator: ctx.sender(),
        name: board_name,
        description: board_description,
        img_url,
        tasks: table::new(ctx),
        reward_token: balance::zero(),
        total_pledged: amount,
        members: vector::empty<address>(),
        created_at: clock::timestamp_ms(clock),
        closed: false,
    };

    // 2. 创建者自动成为成员
    vector::push_back(&mut board.members, ctx.sender());

    // 3. 授予创建者创建者权限
    let creator_cap = CreatorCap {
        id: object::new(ctx),
        board_id: object::id(&board),
    };
    transfer::public_transfer(creator_cap, board.creator);
    //4. 将传进来的余额放入 Board中
    coin::put(&mut board.reward_token, coinType);

    // 5. 更新用户的个人信息
    update_user_profile_on_board_created(portal, board.creator, object::id(&board));

    // 6. 触发 Board 创建事件
    let board_created_event = BoardCreatedEvent<T> {
        name: board.name,
        description: board.description,
        creator: board.creator,
        reward_token_type: type_name::get<T>(),
        reward_token_amount: amount,
        created_at: clock::timestamp_ms(clock)
    };
    event::emit(board_created_event);

    // 7. 将创建好的 Board
    transfer::public_share_object(board);
}

// 创建 Board 的事件结构
public struct BoardCreatedEvent<phantom T> has copy, drop {
    name: String, // 板块名称
    description: String, // 板块描述
    creator: address, // 板块创建者
    reward_token_type: TypeName, // 板块奖励代币的类型
    reward_token_amount: u64, // 板块奖励代币的数量
    created_at: u64, // 板块创建时间
}

// 更新 Board 的基础信息
public entry fun update_board_basic_info<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    new_board_name: Option<String>, // 新板块名称
    new_board_description: Option<String>, // 新板块描述
    new_img_url: Option<String>, // 新板块图片
    clock: &Clock
) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 更新 Board 信息
    // 2.1 更新 Board 名称
    if (new_board_name.is_some()) {
        board.name = destroy_some(new_board_name);
    };
    // 2.2 更新 Board 描述
    if (new_board_description.is_some()) {
        board.description = destroy_some(new_board_description);
    };
    // 2.3 更新 Board 图片
    if (new_img_url.is_some()) {
        board.img_url = destroy_some(new_img_url);
    };
    // 3. 触发 Board 更新事件
    let board_updated_event = BoardUpdatedBasicInfoEvent<T> {
        board_id: object::id(board),
        name: new_board_name,
        description: new_board_description,
        img_url: new_img_url,
        updated_at: clock::timestamp_ms(clock),
    };
    event::emit(board_updated_event);
}

// 更新 Board 的事件结构
public struct BoardUpdatedBasicInfoEvent<phantom T> has copy, drop {
    board_id: ID, // 板块ID
    name: Option<String>, // 板块名称
    description: Option<String>, // 板块描述
    img_url: Option<String>, // 板块图片
    updated_at: u64, // 板块更新时间
}


// 向 Board 中加入更多奖励代币
public entry fun add_reward_token<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    coin: Coin<T>, // 传入的奖励代币
) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 将传入的奖励代币放入 Board 中
    let amount = coin.value();
    coin::put(&mut board.reward_token, coin);
    // 3. 更新 Board 的奖池
    board.total_pledged = board.total_pledged + amount;
    // 4. 触发 Board 添加奖励代币事件
    let board_added_reward_token_event = BoardAddedRewardTokenEvent<T> {
        board_id: object::id(board),
        reward_token_type: type_name::get<T>(),
        add_token_amount: amount,
    };
    event::emit(board_added_reward_token_event);
}

// Board 添加奖励代币的事件
public struct BoardAddedRewardTokenEvent<phantom T> has copy, drop {
    board_id: ID, // 板块ID
    reward_token_type: TypeName, // 奖励代币的类型
    add_token_amount: u64, // 奖励代币的数量
}


// 向 Board 中加入成员
public entry fun join_board<T>(
    portal: &mut UserProfilePortal,
    board: &mut Board<T>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 1. 检查该 Board 是否已关闭
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    // 2. 检查该调用者是否已加入该 Board
    assert!(!vector::contains(&board.members, &ctx.sender()), ERR_MEMBER_EXIST);
    // 3. 将调用者加入 Board 成员列表
    vector::push_back(&mut board.members, ctx.sender());
    // 4. 更新用户的个人信息
    update_user_profile_on_board_joined(portal, ctx.sender(), object::id(board));
    // 4. 触发 Board 添加成员事件
    let board_member_joined_event = BoardMemberJoinedEvent {
        board_id: object::id(board),
        member: ctx.sender(),
        joined_at: clock::timestamp_ms(clock),
    };
    event::emit(board_member_joined_event);
}

// Board 添加成员的事件
public struct BoardMemberJoinedEvent has copy, drop {
    board_id: ID, // 板块ID
    member: address, // 成员地址
    joined_at: u64, // 成员加入时间
}


// 取出 Board 中剩余的奖励代币并将其关闭
#[allow(lint(self_transfer))]
public entry fun withdraw_reward_token_and_close_board<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    ctx: &mut TxContext
){
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. Board 中的奖励代币是否还有剩余
    if (board.reward_token.value() > 0) {
        // 2.1 拿出 Board中的余额并发送个调用者
        let remaining_balance = coin::take(&mut board.reward_token, board.total_pledged, ctx);
        transfer::public_transfer(remaining_balance, ctx.sender());
    };
    // 3. 关闭 Board
    board.closed = true;
}

/*------Task 模块------*/

// 创建 Task
public entry fun create_task<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    task_name: String, // 任务名称
    task_description: String, // 任务描述
    deadline: u64, // 任务截止日期
    mut maxCompletions: u64, // 最大完成次数
    rewardAmount: u64, // 任务奖励金额
    allowSelfCheck: bool, // 是否允许自检
    config: String, // 任务配置
    clock: &Clock,
    ctx: &mut TxContext,

) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 创建 Task
    // 2.1 验证 maxCompletions 的值
    if (maxCompletions <= 0) {
        maxCompletions = 1;
    };
    // 2.2 验证 rewardAmount 的值是否大于 Board 的奖励代币总数
    if (rewardAmount > board.total_pledged) {
        abort ERR_REWARD_OVERFLOW_POOL
    };
    let mut task = Task {
        id: object::new(ctx),
        name: task_name,
        creator: ctx.sender(),
        description: task_description,
        deadline,
        maxCompletions,
        numCompletions: 0,
        reviewers: vector::empty<address>(),
        submissions: table::new(ctx),
        completed: false,
        rewardAmount,
        created_at: clock::timestamp_ms(clock),
        cancelled: false,
        config,
        allowSelfCheck,
    };
    // 2.3 将创建者加入到 Task 的 reviewers 列表中
    vector::push_back(&mut task.reviewers, ctx.sender());
    // 3. 触发 Task 创建的事件
    let task_created_event = TaskCreatedEvent {
        board_id: object::id(board),
        task_id: object::id(&task),
        task_name: task.name,
        creator: task.creator,
        description: task.description,
        deadline: task.deadline,
        maxCompletions: task.maxCompletions,
        rewardAmount: task.rewardAmount,
        created_at: task.created_at,
    };
    event::emit(task_created_event);
    // 4. 将创建好的 Task 放入 Board 中
    let task_id_temp = object::borrow_id(&task);
    table::add(&mut board.tasks, object::id_to_address(task_id_temp), task);
}

// 定义创建 Task 的事件
public struct TaskCreatedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: ID, // 任务ID
    task_name: String, // 任务名称
    creator: address, // 任务创建者
    description: String, // 任务描述
    deadline: u64, // 任务截止日期
    maxCompletions: u64, // 最大完成次数
    rewardAmount: u64, // 任务奖励金额
    created_at: u64, // 任务创建时间
}

// 更新 Task
public entry fun update_task<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    task_id: address, // 任务ID
    new_task_name: Option<String>, // 新任务名称
    new_task_description: Option<String>, // 新任务描述
    new_deadline: Option<u64>, // 新任务截止日期
    new_maxCompletions: Option<u64>, // 新最大完成次数
    new_rewardAmount: Option<u64>, // 新任务奖励金额
    new_allowSelfCheck: Option<bool>, // 是否允许自检
    new_config: Option<String>, // 新任务配置
    clock: &Clock
) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 获取 Task
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 更新 Task 信息
    // 3.1 更新 Task 名称
    if (new_task_name.is_some()) {
        task.name = destroy_some(new_task_name);
    };
    // 3.2 更新 Task 描述
    if (new_task_description.is_some()) {
        task.description = destroy_some(new_task_description);
    };
    // 3.3 更新 Task 截止日期
    if (new_deadline.is_some()) {
        task.deadline = destroy_some(new_deadline);
    };
    // 3.4 更新 Task 最大完成次数
    if (new_maxCompletions.is_some()) {
        task.maxCompletions = destroy_some(new_maxCompletions);
    };
    // 3.5 更新 Task 奖励金额
    if (new_rewardAmount.is_some()) {
        task.rewardAmount = destroy_some(new_rewardAmount);
    };
    // 3.6 更新 Task 是否允许自检
    if (new_allowSelfCheck.is_some()) {
        task.allowSelfCheck = destroy_some(new_allowSelfCheck);
    };
    // 3.7 更新 Task 配置
    if (new_config.is_some()) {
        task.config = destroy_some(new_config);
    };
    // 4. 触发 Task 更新事件
    let task_updated_event = TaskUpdatedEvent {
        board_id: object::id(board),
        task_id,
        updated_at: clock::timestamp_ms(clock),
    };
    event::emit(task_updated_event);
}

// Task 更新事件
public struct TaskUpdatedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    updated_at: u64, // 任务更新时间
}

// 取消 Task
public entry fun cancel_task<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    task_id: address // 任务ID
) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 获取 Task
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 取消 Task
    task.cancelled = true;
    // 4. 触发 Task 取消事件
    let task_cancelled_event = TaskCancelledEvent {
        board_id: object::id(board),
        task_id,
    };
    event::emit(task_cancelled_event);
}

// Task 取消事件
public struct TaskCancelledEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
}

/*------Submission 模块------*/

// 提交的数据结构
public struct Submission has key, store {
    id: UID, // 提交ID
    task_id: address, // 任务ID
    submitter: address, // 提交者
    proof: String, // 完成证明
    status: SubmissionStatus, // 提交状态
    submitted_at: u64, // 提交时间
    review_comment: String, // 审核者
}

// 提交状态的定义
public enum SubmissionStatus has store, copy, drop {
    Rejected,
    UnderReview,
    Approved
}

// 创建提交任务完成证明
public entry fun submit_task_proof<T>(
    board: &mut Board<T>, // 板块
    task_id: address, // 任务ID
    proof: String, // 完成证明
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 1. 检查该 Board 是否已关闭
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    // 2. 获取 Task && 定义一个 Board ID 的临时变量
    let board_id_temp = object::id(board);
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 检查当前任务是否已经完成 && 检查当前任务是否已经取消
    assert!(task.completed == false, ERR_TASK_IS_COMPLETED);
    assert!(task.cancelled == false, ERR_TASK_IS_CANCELLED);
    // 4. 检查是否已过任务的截止日期
    assert!(clock::timestamp_ms(clock) <= task.deadline, ERR_DEADLINE_PASSED);
    // 5. 检查提交者是否已加入该 Board
    assert!(vector::contains(&board.members, &ctx.sender()), ERR_MEMBER_NOT_EXIST);
    // 6. 检查当前地址是否已经提交过该任务
    assert!(!table::contains(&task.submissions, ctx.sender()), ERR_SUBMISSION_EXIST);
    // 7. 创建 Submission
    let submission = Submission {
        id: object::new(ctx),
        task_id,
        submitter: ctx.sender(),
        proof,
        status: SubmissionStatus::UnderReview,
        submitted_at: clock::timestamp_ms(clock),
        review_comment: string::utf8(b""),
    };
    // 8. 触发 Submission 创建事件
    let submission_created_event = SubmissionCreatedEvent {
        board_id: board_id_temp,
        task_id,
        submission_id: object::id(&submission),
        submitter: submission.submitter,
        proof: submission.proof,
        submitted_at: submission.submitted_at,
    };
    event::emit(submission_created_event);
    // 9. 将 Submission 放入 Task 中
    table::add(&mut task.submissions, ctx.sender(), submission);
}

// 提交任务完成证明的事件
public struct SubmissionCreatedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    submission_id: ID, // 提交ID
    submitter: address, // 提交者
    proof: String, // 完成证明
    submitted_at: u64, // 提交时间
}

// 审核提交的任务完成证明(由 Board 的审核者调用)
public entry fun review_submission<T>(
    board: &mut Board<T>, // 板块
    task_id: address, // 任务ID
    submitter: address, // 提交者
    review_comment: String, // 审核者评论
    status: u64, // 审核状态
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 1. 检查该 Board 是否已关闭
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    // 2. 获取 Task && 定义一个 Board ID 的临时变量
    let board_id_temp = object::id(board);
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 获取 Submission
    let submission = table::borrow_mut(&mut task.submissions, submitter);
    // 4. 检查当前任务是否已经完成 && 检查当前任务是否已经取消
    assert!(task.completed == false, ERR_TASK_IS_COMPLETED);
    assert!(task.cancelled == false, ERR_TASK_IS_CANCELLED);
    // 5. 检查是否已过任务的截止日期
    assert!(clock::timestamp_ms(clock) <= task.deadline, ERR_DEADLINE_PASSED);
    // 6. 检查审核者是否在任务的审核者列表中
    assert!(vector::contains(&task.reviewers, &ctx.sender()), ERR_MEMBER_NOT_EXIST);
    // 7. 更新 Submission 的状态和审核者评论
    // 7.1. 更新 Submission 的状态
    if (status == REJECTED) {
        submission.status = SubmissionStatus::Rejected;
    } else if (status == APPROVED) {
        submission.status = SubmissionStatus::Approved;
        // 如果通过，则触发发放奖励的逻辑
        // 7.1.1. 检查当前任务的完成次数是否已经达到最大完成次数
        assert!(task.numCompletions < task.maxCompletions, ERR_MAX_COMPLETIONS_REACHED);
        // 7.1.2. 发放奖励
        // 7.1.2.1. 检查整个Board剩余的奖励数量是否足够
        assert!(board.total_pledged >= task.rewardAmount, ERR_REWARD_AMOUNT_NOT_ENOUGH);
        // 7.1.2.2. 从 Board 中拿出该任务的奖励
        let coin_reward = coin::take(&mut board.reward_token, task.rewardAmount, ctx);
        // 7.1.2.3. 减去 Board 的剩余奖励金额
        board.total_pledged = board.total_pledged - task.rewardAmount;
        //7.1.2.4. 触发奖励发放事件
        let reward_distributed_event = RewardDistributedEvent {
            board_id: board_id_temp,
            task_id,
            participant: submission.submitter,
            reward_amount: task.rewardAmount,
            reward_token_type: type_name::get<T>(),
            distributed_at: clock::timestamp_ms(clock),
        };
        event::emit(reward_distributed_event);
        // 7.1.2.5. 给完成任务的参与者发放奖励
        transfer::public_transfer(coin_reward, submission.submitter);

        // 7.1.3. 更新当前任务的完成次数
        task.numCompletions =  task.numCompletions + 1;
        // 7.1.4. 如果当前任务的完成次数已经达到最大完成次数，则将当前任务的状态设置为完成
        if (task.numCompletions >= task.maxCompletions) {
            task.completed = true;
            // 7.1.4.1 触发任务完成事件
            let task_completed_event = TaskCompletedEvent {
                board_id: board_id_temp,
                task_id,
                completed_at: clock::timestamp_ms(clock),
            };
            event::emit(task_completed_event);
        };
    };
    // 7.2. 更新审核者评论
    submission.review_comment = review_comment;
    // 8. 触发 Submission 审核事件
    let submission_reviewed_event = SubmissionReviewedEvent {
        board_id: board_id_temp,
        task_id,
        submission_id: object::id(submission),
        reviewer: ctx.sender(),
        review_comment,
        reviewed_at: clock::timestamp_ms(clock),
    };
    event::emit(submission_reviewed_event);
}

// 提交任务完成证明的事件
public struct SubmissionReviewedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    submission_id: ID, // 提交ID
    reviewer: address, // 审核者
    review_comment: String, // 审核者评论
    reviewed_at: u64, // 审核时间
}

// 任务完成事件
public struct TaskCompletedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    completed_at: u64, // 任务完成时间
}

// 重新提交被拒绝的任务
public entry fun resubmit_task_proof<T>(
    board: &mut Board<T>, // 板块
    task_id: address, // 任务ID
    proof: String, // 完成证明
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 1. 检查该 Board 是否已关闭
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    // 2. 获取 Task && 定义一个 Board ID 的临时变量
    let board_id_temp = object::id(board);
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 获取 Submission
    let submission = table::borrow_mut(&mut task.submissions, ctx.sender());
    // 4. 检查当前任务是否已经完成 && 检查当前任务是否已经取消
    assert!(task.completed == false, ERR_TASK_IS_COMPLETED);
    assert!(task.cancelled == false, ERR_TASK_IS_CANCELLED);
    // 5. 检查是否已过任务的截止日期
    assert!(clock::timestamp_ms(clock) <= task.deadline, ERR_DEADLINE_PASSED);
    // 6. 检查 Submission 的状态是否为 Rejected
    assert!(submission.status == SubmissionStatus::Rejected, ERR_SUBMISSION_NOT_REJECT);
    // 7. 更新 Submission 的状态和完成证明
    submission.status = SubmissionStatus::UnderReview;
    submission.proof = proof;
    // 8. 触发 Submission 重新提交事件
    let submission_resubmitted_event = SubmissionResubmittedEvent {
        board_id: board_id_temp,
        task_id,
        submission_id: object::id(submission),
        submitter: ctx.sender(),
        proof,
        resubmitted_at: clock::timestamp_ms(clock),
    };
    event::emit(submission_resubmitted_event);
}

// 重新提交任务完成证明的事件
public struct SubmissionResubmittedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    submission_id: ID, // 提交ID
    submitter: address, // 提交者
    proof: String, // 完成证明
    resubmitted_at: u64, // 重新提交时间
}

/*------Claim Reward 模块------*/

// 奖励发放事件
public struct RewardDistributedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    participant: address, // 参与者
    reward_amount: u64, // 奖励金额
    reward_token_type: TypeName, // 奖励代币类型
    distributed_at: u64, // 奖励发放时间
}

/*------其他模块------*/

// board 的创建者为自己的 board 中的 Task 加入审核者的方法
public entry fun add_reviewer<T>(
    creator_cap: &CreatorCap, // 板块创建者权限
    board: &mut Board<T>, // 板块
    task_id: address, // 任务ID
    reviewer: vector<address> // 审核者
) {
    // 1. 检查该 Board 是否已关闭 && 对该调用者的当前权限进行验证
    assert!(board.closed == false, ERR_BOARD_IS_CLOSE);
    assert!(creator_cap.board_id == object::id(board), ERR_BOARD_NO_PERMISSION);
    // 2. 获取 Task && 定义一个 Board ID 的临时变量
    let board_id_temp = object::id(board);
    let task = table::borrow_mut(&mut board.tasks, task_id);
    // 3. 检查当前任务是否已经取消
    assert!(task.cancelled == false, ERR_TASK_IS_CANCELLED);
    // 4. 检查审核员是否已经存在于该 Task 的审核员列表中
    let mut i = 0;
    let length = vector::length(&reviewer);
    while (i < length) {
        assert!(!vector::contains(&task.reviewers, &reviewer[i]), ERR_REVIEWER_EXIST);
        i = i + 1;
    };
    // 5. 将审核员添加到该 Task 的审核员列表中
    let mut j = 0;
    while (j < length) {
        vector::push_back(&mut task.reviewers, reviewer[j]);
        j = j + 1;
    };
    // 6. 触发 Task 审核员添加事件
    let reviewer_added_event = ReviewerAddedEvent {
        board_id: board_id_temp,
        task_id,
        new_reviewer: reviewer,
    };
    event::emit(reviewer_added_event);
}

// task中加入审核员的事件
public struct ReviewerAddedEvent has copy, drop {
    board_id: ID, // 板块ID
    task_id: address, // 任务ID
    new_reviewer: vector<address> // 新加入的审核员列表
}




















