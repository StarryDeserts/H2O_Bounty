module suibountyboard::UserProfilePortal;
use std::string::String;
use sui::event;
use sui::clock::{Self, Clock};
use sui::table::{Self, Table};

const ERR_USER_PROFILE_NOT_FOUND: u64 = 1; // 用户档案不存在
const ERR_USER_PROFILE_ALREADY_EXISTS: u64 = 2; // 用户档案已存在

// 用户档案一次性见证
public struct USERPROFILEPORTAL has drop {}

// 用户地址
public struct UserProfile has key, store {
    id: UID,
    username: String, // 用户名
    email: String, // 邮箱
    role: String, // 角色
    bio: String, // 个人简介
    user_address: address, // 用户地址
    created_boards: vector<ID>, // 创建的赏金板列表
    join_boards: vector<ID>, // 加入的赏金板列表
    created_at: u64, // 创建时间
}

// 用户档案门户
public struct UserProfilePortal has key, store {
    id: UID,
    user_profiles: Table<address, UserProfile>, // 用户档案表
    user_addresses: vector<address>, // 用户地址列表
}

// 初始化用户档案门户
fun init(otw: USERPROFILEPORTAL, ctx: &mut TxContext) {
    // 发布者地址
    let publisher_address = ctx.sender();
    // 发布者声明，一次性见证
    let publisher = sui::package::claim(otw, ctx);
    // 创建 UserProfilePortal 结构，全局存储所有用户的档案信息
    let user_profile_portal = UserProfilePortal {
        id: object::new(ctx),
        user_profiles: table::new(ctx),
        user_addresses: vector::empty<address>(),
    };
    // 将发布的一次性见证转移发布者
    transfer::public_transfer(publisher, publisher_address);
    // 发布用户档案门户
    transfer::public_share_object(user_profile_portal);
}

// 创建新的用户档案
public entry fun create_user_profile(
    portal: &mut UserProfilePortal,
    username: String,
    email: String,
    role: String,
    bio: String,
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 检查用户档案是否已存在
    assert!(!table::contains(&portal.user_profiles, ctx.sender()), ERR_USER_PROFILE_ALREADY_EXISTS);
    // 创建新的用户档案
    let user_profile = UserProfile {
        id: object::new(ctx),
        username,
        email,
        role,
        bio,
        user_address: ctx.sender(),
        created_boards: vector::empty<ID>(),
        join_boards: vector::empty<ID>(),
        created_at: clock::timestamp_ms(clock),
    };
    portal.user_profiles.add(ctx.sender(), user_profile);
    portal.user_addresses.push_back(ctx.sender());

    // 触发用户档案创建事件
    let userprofile_created_event = UserProfileCreatedEvent {
        username,
        email,
        role,
        bio,
        user_address: ctx.sender(),
        created_at: clock::timestamp_ms(clock),
    };
    event::emit(userprofile_created_event);
}

// 用户档案创建事件
public struct UserProfileCreatedEvent has copy, drop {
    username: String,
    email: String,
    role: String,
    bio: String,
    user_address: address,
    created_at: u64,
}

// 更新用户档案的基本信息
public entry fun update_user_profile(
    portal: &mut UserProfilePortal,
    user: address,
    new_name: Option<String>,
    new_email: Option<String>,
    new_role: Option<String>,
    new_bio: Option<String>
) {
    let profiles = &mut portal.user_profiles;

    // 检查用户档案是否存在
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);

    // 更新用户档案
    let profile = table::borrow_mut(profiles, user);
    if (option::is_some(&new_name)) {
        profile.username = option::destroy_some(new_name);
    };
    if (option::is_some(&new_email)) {
        profile.email = option::destroy_some(new_email);
    };
    if (option::is_some(&new_role)) {
        profile.role = option::destroy_some(new_role);
    };
    if (option::is_some(&new_bio)) {
        profile.bio = option::destroy_some(new_bio);
    };

    // 触发用户档案更新事件
    let userprofile_updated_event = UserProfileUpdatedEvent {
        username: new_name,
        email: new_email,
        role: new_role,
        bio: new_bio,
    };
    event::emit(userprofile_updated_event);
}

// 更新用户档案事件
public struct UserProfileUpdatedEvent has copy, drop {
    username: Option<String>,
    email: Option<String>,
    role: Option<String>,
    bio: Option<String>,
}

// 当用户创建赏金板时，更新用户档案
public(package) fun update_user_profile_on_board_created(
    portal: &mut UserProfilePortal,
    user: address,
    board_id: ID
) {
    let profiles = &mut portal.user_profiles;
    // 检查用户档案是否存在
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);
    // 更新用户档案
    let profile = table::borrow_mut(profiles, user);
    // 将赏金板 ID 添加到用户档案的创建的赏金板列表中
    profile.created_boards.push_back(board_id);
}

// 当用户加入赏金板时，更新用户档案
public(package) fun update_user_profile_on_board_joined(
    portal: &mut UserProfilePortal,
    user: address,
    board_id: ID
) {
    let profiles = &mut portal.user_profiles;
    // 检查用户档案是否存在
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);
    // 更新用户档案
    let profile = table::borrow_mut(profiles, user);
    // 将赏金板 ID 添加到用户档案的加入的赏金板列表中
    profile.join_boards.push_back(board_id);
}

/*------已读方法------*/

// 获取用户档案
public fun get_user_profile(
    portal: &UserProfilePortal,
    user: address
): &UserProfile {
    let profiles = &portal.user_profiles;
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);
    table::borrow(profiles, user)
}

// 获取所有用户的地址
public fun get_all_user_addresses(
    portal: &UserProfilePortal
): &vector<address> {
    &portal.user_addresses
}

// 获取当前用户创建的所有赏金板的信息
public fun get_user_created_boards(
    portal: &UserProfilePortal,
    user: address
): &vector<ID>  {
    let profiles = &portal.user_profiles;
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);
    let profile = table::borrow(profiles, user);
    &profile.created_boards
}

// 获取当前用户加入的所有赏金板的信息
public fun get_user_joined_boards(
    portal: &UserProfilePortal,
    user: address
): &vector<ID>  {
    let profiles = &portal.user_profiles;
    assert!(table::contains(profiles, user), ERR_USER_PROFILE_NOT_FOUND);
    let profile = table::borrow(profiles, user);
    &profile.join_boards
}

// 获取所有用户创建的 Board 信息
public fun get_all_user_created_boards(
    portal: &UserProfilePortal,
): vector<ID> {
    // 创建一个空的向量，用于存储所有用户创建的Board ID
    let mut all_board = vector::empty<ID>();
    // 获取所有用户的地址
    let user_addresses = &portal.user_addresses;
    let mut i = 0;
    let len = vector::length(user_addresses);

    while (i < len) {
        let user_address = vector::borrow(user_addresses, i);
        let user_profile = table::borrow(&portal.user_profiles, *user_address);

        // 合并该用户创建的所有Board ID到结果向量中
        let mut j = 0;
        let boards_len = vector::length(&user_profile.created_boards);
        while (j < boards_len) {
            let board_id = vector::borrow(&user_profile.created_boards, j);
            vector::push_back(&mut all_board, *board_id);
            j = j + 1;
        };
        i = i + 1;
    };
    all_board
}

