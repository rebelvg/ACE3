#define DEBUG_MODE_FULL
#include "script_component.hpp"

LOG("Adding ACE_Settings to CBA_settings");

// Init Vars:
GVAR(cbaSettings_forcedSettings) = [];
GVAR(cbaSettings_missionSettings) = [];
GVAR(settings) = []; // will stay empty - for BWC?

// Add Event Handlers:
["CBA_beforeSettingsInitialized", {
    TRACE_1("CBA_beforeSettingsInitialized EH",_this);

    // First: Process missionConfig settings:
    {
        _x params ["_settingName", "_value"];
        TRACE_2("setSettingMission from missionConfig",_settingName,_value);
        ["CBA_settings_setSettingMission", [_settingName, _value, true]] call CBA_fnc_localEvent;
    } forEach GVAR(cbaSettings_missionSettings);
    GVAR(cbaSettings_missionSettings) = nil;

    // Second: Read settings from mission params
    [] call FUNC(readSettingsFromParamsArray);

    // Third: Event so that ACE_Modules have their settings loaded:
    [QGVAR(initSettingsFromModules), []] call CBA_fnc_localEvent;
    
    TRACE_1("Finished mission settings",_this);
}] call CBA_fnc_addEventHandler;

["CBA_settingsInitialized", {
    TRACE_1("CBA_settingsInitialized EH",_this);
    if !(SLX_XEH_MACHINE select 8) then {WARNING("PostInit not finished");};
    INFO("Settings initialized.");

    //Event that settings are safe to use:
    ["ace_settingsInitialized", []] call CBA_fnc_localEvent;

    //Set init finished and run all delayed functions:
    GVAR(settingsInitFinished) = true;
    INFO_1("%1 delayed functions running.",count GVAR(runAtSettingsInitialized));
    {
        (_x select 1) call (_x select 0);
        false
    } count GVAR(runAtSettingsInitialized);
    GVAR(runAtSettingsInitialized) = nil; //cleanup
}] call CBA_fnc_addEventHandler;

private _start = diag_tickTime;

private _settingsConfig = configFile >> "ACE_Settings";
private _countOptions = count _settingsConfig;
TRACE_1("Reading settings from configFile",_countOptions);
for "_index" from 0 to (_countOptions - 1) do {
    private _optionEntry = _settingsConfig select _index;
    if (isNil (configName _optionEntry)) then {
        [_optionEntry] call FUNC(cbaSettings_loadFromConfig);
    } else {
        WARNING_1("Setting [%1] - Already defined from somewhere else??",_varName);
    };
};

_settingsConfig = missionConfigFile >> "ACE_Settings";
_countOptions = count _settingsConfig;
TRACE_1("Reading settings from missionConfigFile",_countOptions);
for "_index" from 0 to (_countOptions - 1) do {
    private _optionEntry = _settingsConfig select _index;
    private _settingName = configName _optionEntry;
    if ((toLower _settingName) in GVAR(cbaSettings_forcedSettings)) then {
        WARNING_1("Setting [%1] - Already Forced - ignoring missionConfig",_varName);
    } else {
        if (isNil _settingName) then {
            // New setting, that was first defined in missionConfigFile
            [_optionEntry] call FUNC(cbaSettings_loadFromConfig);
        } else {
            private _value = (_optionEntry >> "value") call BIS_fnc_getCfgData;
            if (isNil "_value") exitWith {ERROR_1("Setting [%1] - Has bad value",_settingName);};
            TRACE_2("queuing missionConfig setting",_settingName,_value);
            GVAR(cbaSettings_missionSettings) pushBack [_settingName, _value];
        };
    };
};

INFO_1("Parsed Settings Configs [%1 ms]",(1000 * (diag_tickTime - _start)) toFixed 1);
