if not _G.charSelectExists then return end

gXStates = {}

local function x_reset_extra_states(index)
    if index == nil then index = 0 end
    gXStates[index] = {
        index = network_global_index_from_local(0),
    }
end
for i = 0, MAX_PLAYERS - 1 do
    x_reset_extra_states(i)
end

local function x_update_walking_speed(m)
    if not m then return end

    local maxTargetSpeed = 50.0;
    if (m.floor ~= nil and m.floor.type == SURFACE_SLOW) then
        maxTargetSpeed = 40.0;
    end

    local targetSpeed = maxTargetSpeed*m.intendedMag/32 * (1 - math.clamp(math.abs(m.intendedYaw - m.faceAngle.y)/0x8000, 0, 0x8000))

    if (m.quicksandDepth > 10.0) then
        targetSpeed = targetSpeed * 6.25 / m.quicksandDepth;
    end

    m.forwardVel = math.lerp(m.forwardVel, targetSpeed, 0.04)

    --[[
    if (m.forwardVel <= 0.0) then
        m.forwardVel = m.forwardVel + 1.1;
    elseif (m.forwardVel <= targetSpeed) then
        m.forwardVel = m.forwardVel + 1.1 - m.forwardVel / 43.0;
    elseif (m.floor ~= nil and m.floor.normal.y >= 0.95) then
        m.forwardVel = m.forwardVel - 1.0;
    end
    ]]

    --if (m.forwardVel > 48.0) then
    --    m.forwardVel = 48.0;
    --end

    local turnSpeed = 0x500 * math.clamp(maxTargetSpeed/m.forwardVel, 1, 3) -- Default 0x800
    m.faceAngle.y = m.intendedYaw - approach_s32(math.s16(m.intendedYaw - m.faceAngle.y), 0, turnSpeed, turnSpeed);
    apply_slope_accel(m);
end

local function x_anim_and_audio_for_walk(m)
    if not m then return end
    local val14;
    local marioObj = m.marioObj;
    local val0C = 1;
    local targetPitch = 0;
    local val04;

    val04 = m.intendedMag > m.forwardVel and m.intendedMag or m.forwardVel;

    if (val04 < 4.0) then
        val04 = 4.0;
    end

    if (m.quicksandDepth > 50.0) then
        val14 = math.s32(val04 / 4.0 * 0x10000);
        set_character_anim_with_accel(m, CHAR_ANIM_MOVE_IN_QUICKSAND, val14);
        play_step_sound(m, 19, 93);
        m.actionState = 0;
    else
        while (val0C ~= 0) do
            if m.actionState == 0 then
                if (val04 > 8.0) then
                    m.actionState = 2;
                else
                    --! (Speed Crash) If Mario's speed is more than 2^17.
                    val14 = math.s32(val04 / 4.0 * 0x10000)
                    if (val14 < 0x1000) then
                        val14 = 0x1000;
                    end
                    set_character_anim_with_accel(m, CHAR_ANIM_START_TIPTOE, val14);
                    play_step_sound(m, 7, 22);
                    if (is_anim_past_frame(m, 23)) then
                        m.actionState = 2;
                    end

                    val0C = 0;
                end
            elseif m.actionState == 1 then
                if (val04 > 8.0) then
                    m.actionState = 2;
                else
                    --! (Speed Crash) If Mario's speed is more than 2^17.
                    val14 = math.s32(val04 * 0x10000)
                    if (val14 < 0x1000) then
                        val14 = 0x1000;
                    end
                    set_character_anim_with_accel(m, CHAR_ANIM_TIPTOE, val14);
                    play_step_sound(m, 14, 72);

                    val0C = 0;
                end
            elseif m.actionState == 2 then
                if (val04 < 5.0) then
                    m.actionState = 1;
                elseif (val04 > 22.0) then
                    m.actionState = 3;
                else
                    --! (Speed Crash) If Mario's speed is more than 2^17.
                    val14 = math.s32(val04 / 4.0 * 0x10000);
                    set_character_anim_with_accel(m, CHAR_ANIM_WALKING, val14);
                    play_step_sound(m, 10, 49);

                    val0C = 0;
                end
            elseif m.actionState == 3 then
                if (val04 < 18.0) then
                    m.actionState = 2;
                else
                    --! (Speed Crash) If Mario's speed is more than 2^17.
                    val14 = math.s32(val04 / 4.0 * 0x10000);
                    set_character_anim_with_accel(m, CHAR_ANIM_RUNNING, val14);
                    play_step_sound(m, 9, 45);
                    targetPitch = tilt_body_running(m);

                    val0C = 0;
                end
            else
                val0C = 0;
            end
        end
    end

    marioObj.oMarioWalkingPitch =
        math.s16(approach_s32(marioObj.oMarioWalkingPitch, targetPitch, 0x800, 0x800));
    marioObj.header.gfx.angle.x = marioObj.oMarioWalkingPitch;
end

local ACT_X_WALKING = allocate_mario_action(ACT_GROUP_MOVING)

local function act_x_walking(m)
    if not m then return 0 end
    local startPos = m.pos;
    local startYaw = m.faceAngle.y;

    mario_drop_held_object(m);

    if (should_begin_sliding(m) ~= 0) then
        return set_mario_action(m, ACT_BEGIN_SLIDING, 0);
    end

    --if (m.input & INPUT_FIRST_PERSON ~= 0) then
    --    return begin_braking_action(m);
    --end

    if (m.input & INPUT_A_PRESSED ~= 0) then
        return set_jump_from_landing(m);
    end

    if (check_ground_dive_or_punch(m) ~= 0) then
        return 0;
    end

    if (m.intendedMag < 5 and m.forwardVel < 5) then
        return set_mario_action(m, ACT_IDLE, 0)
    end

    --if (analog_stick_held_back(m) ~= 0 and m.forwardVel >= 16.0) then
    --    return set_mario_action(m, ACT_TURNING_AROUND, 0);
    --end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action(m, ACT_CROUCH_SLIDE, 0);
    end

    m.actionState = 0;

    vec3f_copy(startPos, m.pos);
    x_update_walking_speed(m);

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0);
        set_character_animation(m, CHAR_ANIM_GENERAL_FALL);
    elseif step == GROUND_STEP_NONE then
        x_anim_and_audio_for_walk(m);
        if (m.intendedMag - m.forwardVel > 16.0) then
            set_mario_particle_flags(m, PARTICLE_DUST, 0);
        end
    elseif step == GROUND_STEP_HIT_WALL then
        push_or_sidle_wall(m, startPos);
        m.actionTimer = 0;
    end

    check_ledge_climb_down(m);
    tilt_body_walking(m, startYaw);
    return 0;
end

hook_mario_action(ACT_X_WALKING, act_x_walking)

local function before_x_action(m, nextAct)
    if nextAct == ACT_WALKING then
        return set_mario_action(m, ACT_X_WALKING, 0)
    end
end

local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_X, HOOK_BEFORE_SET_MARIO_ACTION, before_x_action)
end

hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)