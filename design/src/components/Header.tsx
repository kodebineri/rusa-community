import React from 'react';
import {
  Menu,
  Terminal,
  RotateCcw,
  Sun,
  Moon,
  Zap,
  Radio,
  Code2
} from 'lucide-react';
import { ConnectionProfile } from '../types/mongo';

interface HeaderProps {
  connection: ConnectionProfile | null;
  onOpenConnectModal: () => void;
  onDisconnect: () => void;
  onResetData: () => void;
  isTerminalOpen: boolean;
  onToggleTerminal: () => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
  onToggleMobileSidebar: () => void;
  showFlutterMigration: boolean;
  onToggleFlutterMigration: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  connection,
  onOpenConnectModal,
  onDisconnect,
  onResetData,
  isTerminalOpen,
  onToggleTerminal,
  isDarkMode,
  onToggleDarkMode,
  onToggleMobileSidebar,
  showFlutterMigration,
  onToggleFlutterMigration
}) => {
  return (
    <header className="h-14 bg-compass-panel border-b border-compass flex items-center justify-between px-3 sm:px-4 select-none shrink-0 z-30 transition-colors duration-150">
      {/* Brand & Drawer Toggle Zone */}
      <div className="flex items-center gap-2 sm:gap-3">
        {/* Mobile Hamburger Drawer Toggle */}
        <button
          onClick={onToggleMobileSidebar}
          className="md:hidden p-2 -ml-1 text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded-lg transition-colors"
          title="Toggle Navigation Menu"
          aria-label="Toggle Navigation Menu"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* MongoDB Compass Leaf Logo */}
        <div className="flex items-center gap-2 cursor-pointer" onClick={onOpenConnectModal}>
          <div className="w-7 h-7 rounded-md bg-gradient-to-br from-[#00ED64] to-[#00684A] flex items-center justify-center shadow-sm shrink-0">
            <svg viewBox="0 0 24 24" className="w-4 h-4 fill-white" preserveAspectRatio="xMidYMid meet">
              <path d="M12 2C12 2 8 8 8 13.5C8 17.5 10 20 12 22C14 20 16 17.5 16 13.5C16 8 12 2 12 2Z" />
              <path d="M12 2C12 2 11.8 7 11.8 13.5C11.8 17.5 12 22 12 22C12 22 12.2 17.5 12.2 13.5C12.2 7 12 2 12 2Z" fill="#001E2B" opacity="0.3" />
            </svg>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-sm font-bold tracking-tight text-compass-primary font-sans whitespace-nowrap">
              Compass
              <span className="hidden sm:inline"> Web</span>
            </span>
            <span className="hidden lg:inline text-[10px] font-normal text-compass-muted px-1 py-0.2 rounded border border-compass">
              7.0.8
            </span>
          </div>
        </div>

        {/* Connection status indicator */}
        <div className="h-5 w-[1px] bg-compass mx-0.5 sm:mx-1 hidden xs:block" />

        {connection ? (
          <button
            onClick={onOpenConnectModal}
            className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-compass-subtle border border-compass text-xs cursor-pointer hover:bg-compass-hover transition-colors max-w-[110px] xs:max-w-[140px] sm:max-w-[200px] lg:max-w-[320px]"
            title="Click to view connection profile details"
          >
            <div className="w-2 h-2 rounded-full bg-[#00ED64] animate-pulse shrink-0" />
            <span className="text-compass-primary font-medium truncate text-[11px] sm:text-xs">
              {connection.name}
            </span>
          </button>
        ) : (
          <button
            onClick={onOpenConnectModal}
            className="flex items-center gap-1.5 px-2 py-1 rounded bg-amber-500/10 border border-amber-500/30 text-amber-500 dark:text-amber-400 text-xs font-medium hover:bg-amber-500/20 transition-colors"
          >
            <Radio className="w-3.5 h-3.5" />
            <span className="inline text-[11px] sm:text-xs">Connect</span>
          </button>
        )}
      </div>

      {/* Primary Actions Zone */}
      <div className="flex items-center gap-1.5 sm:gap-2">
        {/* Reset sample datasets */}
        <button
          onClick={onResetData}
          title="Reset to sample databases (sample_mflix, sample_analytics, sample_supplies)"
          className="p-2 sm:px-2.5 sm:py-1.5 text-xs text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded-lg border border-transparent hover:border-compass transition-colors"
        >
          <RotateCcw className="w-4 h-4 sm:w-3.5 sm:h-3.5" />
          <span className="hidden lg:inline ml-1.5">Reset Samples</span>
        </button>

        {/* Flutter Migration Hub Toggle */}
        <button
          onClick={onToggleFlutterMigration}
          className={`flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-semibold rounded-lg border transition-colors ${
            showFlutterMigration
              ? 'bg-[#00ED64] text-[#001E2B] border-[#00ED64] shadow-sm font-bold'
              : 'text-compass-secondary hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover border-compass'
          }`}
          title="Toggle React-to-Flutter Migration Code Inspector"
        >
          <Code2 className={`w-3.5 h-3.5 ${showFlutterMigration ? 'text-[#001E2B]' : 'text-compass-accent'}`} />
          <span className="inline">Flutter Code</span>
        </button>

        {/* Mongosh Toggle */}
        <button
          onClick={onToggleTerminal}
          className={`flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-mono font-medium rounded-lg border transition-colors ${
            isTerminalOpen
              ? 'bg-[#00684A] text-white border-[#00ED64]/40 shadow-sm'
              : 'text-compass-secondary hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover border-compass'
          }`}
          title="Toggle mongosh Interactive Shell"
        >
          <Terminal className="w-3.5 h-3.5 text-[#00684A] dark:text-[#00ED64]" />
          <span className="hidden sm:inline">_mongosh</span>
        </button>

        {/* Light/Dark Mode Toggle */}
        <button
          onClick={onToggleDarkMode}
          className="p-2 text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded-lg border border-transparent hover:border-compass transition-colors"
          title={isDarkMode ? 'Switch to Light theme' : 'Switch to Dark theme'}
          aria-label={isDarkMode ? 'Switch to Light theme' : 'Switch to Dark theme'}
        >
          {isDarkMode ? (
            <Sun className="w-4 h-4 text-amber-400" />
          ) : (
            <Moon className="w-4 h-4 text-slate-700" />
          )}
        </button>

        {/* Connect / Disconnect */}
        {connection ? (
          <button
            onClick={onDisconnect}
            className="px-2.5 sm:px-3 py-1.5 text-xs font-medium text-rose-500 dark:text-rose-300 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 rounded-lg transition-colors whitespace-nowrap"
          >
            <span className="hidden sm:inline">Disconnect</span>
            <span className="sm:hidden">Exit</span>
          </button>
        ) : (
          <button
            onClick={onOpenConnectModal}
            className="px-3 py-1.5 text-xs font-semibold bg-compass-accent rounded-lg transition-colors shadow-sm whitespace-nowrap flex items-center gap-1.5"
          >
            <Zap className="w-3.5 h-3.5" />
            <span>Connect</span>
          </button>
        )}
      </div>
    </header>
  );
};
