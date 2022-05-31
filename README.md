# Transform Transfer for Godot

A Godot plugin to transfer transformations from one spatial scene to any other spatial scenes

## What is it for?

If you ever need to snap one spatial scene to another, that's how you do it without manually retyping the transforms. This is potentially usefull when building levels from 3rd-party made layouts/whiteboxes using actual assets, or when you just need to snap two objects together.

## Installation

This plugin is installed the same as other Godot plugins.

Copy the folder `addons/dreadpon.transform_transfer/` to `res://addons/` in your Godot project and enable it from `Project -> Project Settings -> Plugins`.

## Support

This plugin was developed and tested using Godot v3.4.2, but should work fine on most 3.x versions.

## Usage

1. Open any scene in your project.
2. Select 2 or more spatial scenes (make sure to explicitly select the last scene).
3. Click `Transform Transfer` in the toolbar.
    - Your last selected scene becomes the **source** from which the transformations are taken.
    - All **other** scenes will have their global transforms set to that of the **source**.

**NOTE:** It's important to explicitly select the **source** alone (`Ctrl + Click` instead of `Shift + Click`) since apparently Godot doesn't have native selection ordering.