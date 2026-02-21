---@meta _

---@class (exact) Mod_ModInfo
---@field name string The name of the mod.
---@field file string
---@field currentDirectory string
---@field modsDirectory string

---@class Mod_Logger
local logger = {}
---@param ... any
function logger.trace(value, ...) end

---@param ... any
function logger.debug(value, ...) end

---@param ... any
function logger.info(value, ...) end

---@param ... any
function logger.warn(value, ...) end

---@param ... any
function logger.error(value, ...) end

---@param ... any
function logger.fatal(value, ...) end

---@param newLevel? _LogLevel
---@param newLevelForFatalError? _LogLevel
function logger.setLevel(newLevel, newLevelForFatalError) end

--------------------------------------------------------------------------------
--#region Fixes things from UE4SS Types.lua

---@class LocalObject

---@class FName : LocalObject
FName = {}
--Returns the string for this FName.
---@return string
function FName.ToString() end

--#endregion
