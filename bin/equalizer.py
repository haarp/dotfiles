#!/usr/bin/python3
# pipewire-filter-chain 3-band equalizer GUI
# https://gkiagia.gr/2024-01-19-chatgpt-powered-equalizer/
#
# Run with: python3 equalizer.py <node id>
#   where <node id> is meant to be the "Audio/Sink" node of the "Equalizer Sink"
#
# 98% written by ChatGPT
#
# TODO:
# make it compatible with node.name instead of node_id
# dynamically detect number of dials
# add Q and freq
# add dscriptions to gui

import gi
import subprocess
import argparse
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
import json

class EqualizerApp(Gtk.Window):
    def __init__(self, node_id):
        Gtk.Window.__init__(self, title="Equalizer")
        self.set_default_size(400, 200)

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.add(self.box)

        self.sliders = []

        try:
            result = subprocess.run(['pw-dump', str(node_id)], capture_output=True, text=True, check=True)
            output = result.stdout
            data = json.loads(output)
            props = []

            for i in range(10):
                try:
                    props = data[i]["info"]["params"]["Props"][1]["params"]
                    break
                except KeyError:
                    continue

            for i in range(3):
                gain = float(props[5 + 18 * i])
                slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, -30.0, 20.0, 0.25)
                slider.set_value(gain)
                slider.connect("value-changed", self.on_slider_moved, node_id, i + 1)
                self.sliders.append(slider)
                self.box.pack_start(slider, True, True, 0)

        except subprocess.CalledProcessError as e:
            print(f"Error: {e}")

    def on_slider_moved(self, widget, node_id, band_number):
        value = widget.get_value()
        command = f'pw-cli s {node_id} Props \'{{ "params": [ "eq_band_{band_number}:Gain", {value} ] }}\''
        try:
            subprocess.run(command, shell=True, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error: {e}")

def parse_arguments():
    parser = argparse.ArgumentParser(description='3 Band Equalizer')
    parser.add_argument('node_id', type=int, help='Node ID')
    return parser.parse_args()

args = parse_arguments()
win = EqualizerApp(args.node_id)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
